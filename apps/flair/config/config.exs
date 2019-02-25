use Mix.Config

config :kaffe,
  consumer: [
    endpoints: [localhost: 9092],
    topics: [data_topic, registry_topic],
    consumer_group: "forklift-group",
    message_handler: Forklift.MessageProcessor,
    offset_reset_policy: :reset_to_earliest,
    start_with_earliest_message: true,
    max_bytes: 1_000_000,
    worker_allocation_strategy: :worker_per_topic_partition,
  ]
