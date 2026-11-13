"""Streaming word count with PyFlink."""

import argparse
import re
import sys

from pyflink.common import Configuration, Types
from pyflink.datastream import DataStream, RuntimeExecutionMode, StreamExecutionEnvironment
from pyflink.table import StreamTableEnvironment


# Sample sentences from Hamlet.
SENTENCES = (
    "To be, or not to be, that is the question.",
    "Whether 'tis nobler in the mind to suffer",
    "The slings and arrows of outrageous fortune,",
    "Or to take arms against a sea of troubles",
    "And by opposing end them. To die, to sleep,",
)


def split_words(sentence):
    """Emit one lowercase (word, 1) record for each word."""
    for word in re.split(r"\W+", sentence.lower(), flags=re.ASCII):
        if word:
            yield word, 1


def word_counts(sentences: DataStream) -> DataStream:
    """Split sentences into words and maintain a running count per word."""
    return (
        sentences
        .flat_map(split_words, output_type=Types.TUPLE([Types.STRING(), Types.LONG()]))
        .name("Split sentences into words")
        .key_by(lambda item: item[0], key_type=Types.STRING())
        .sum(1)
        .name("Running count per word")
    )


def live_sentences(env: StreamExecutionEnvironment, rate: int) -> DataStream:
    """Use Flink's built-in DataGen connector to pace an unbounded source."""
    table_env = StreamTableEnvironment.create(env)
    table_env.execute_sql(f"""
        CREATE TEMPORARY TABLE sentence_indices (
            sentence_index INT
        ) WITH (
            'connector' = 'datagen',
            'rows-per-second' = '{rate}',
            'fields.sentence_index.min' = '0',
            'fields.sentence_index.max' = '{len(SENTENCES) - 1}',
            'scan.parallelism' = '1'
        )
    """)
    return (
        table_env.to_data_stream(table_env.from_path("sentence_indices"))
        .map(lambda row: SENTENCES[row[0]], output_type=Types.STRING())
        .name("Choose a Hamlet sentence")
        .set_parallelism(1)
    )


def positive_int(value):
    number = int(value)
    if number < 1:
        raise argparse.ArgumentTypeError("must be at least 1")
    return number


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--stream", action="store_true",
                        help="emit random sample sentences continuously until cancelled")
    parser.add_argument("--parallelism", type=positive_int, default=1,
                        help="parallelism of the word-count operators (default: 1)")
    parser.add_argument("--rate", type=positive_int, default=1,
                        help="sentences per second in --stream mode (default: 1)")
    parser.add_argument("--web-ui", action="store_true",
                        help="enable the Web UI for a local run")
    parser.add_argument("--rest-port", type=positive_int, default=8081,
                        help="local Web UI port (default: 8081)")
    args = parser.parse_args()
    if args.rest_port > 65535:
        parser.error("--rest-port must be between 1 and 65535")

    config = Configuration()
    # Flush small Python bundles promptly so students can watch counts arrive.
    config.set_integer("python.fn-execution.bundle.size", 1)
    if args.web_ui:
        config.set_boolean("local.start-webserver", True)
        config.set_integer("rest.port", args.rest_port)
        config.set_string("rest.bind-address", "127.0.0.1")
        config.set_string("rest.address", "localhost")

    # Respects a cluster context supplied by `flink run`; otherwise runs locally.
    env = StreamExecutionEnvironment.get_execution_environment(config)
    env.set_runtime_mode(RuntimeExecutionMode.STREAMING)
    env.set_parallelism(args.parallelism)
    env.set_python_executable(sys.executable)

    if args.stream:
        sentences = live_sentences(env, args.rate)
    else:
        sentences = env.from_collection(list(SENTENCES), type_info=Types.STRING())
        sentences.name("Five Hamlet sentences")

    word_counts(sentences).print().name("StdoutSink")
    env.execute("Python Flink Lab - Streaming Word Count")


if __name__ == "__main__":
    main()
