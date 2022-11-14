import Config

config :scrybot,
  workers: :auto

config :logger,
  backends: [
    {FlexLogger, :file_logger},
    {FlexLogger, :default_logger}
  ]

config :logger, :file_logger,
  logger: LoggerFileBackend,
  default_level: :debug,
  level_config: [],
  metadata: [:application, :module, :function],
  format: "$time $metadata[$level]$levelpad $message\n",
  path: "log/scrybot.log"

config :logger, :default_logger,
  logger: :console,
  default_level: :info,
  level_config: [
    [application: :scrybot, module: Scrybot, level: :debug]
  ],
  format: "$time [$level]$levelpad $message\n"

config :tesla, Tesla.Middleware.Telemetry, disable_legacy_event: true

config :tesla, :adapter, Tesla.Adapter.Mint

import_config "config.secret.exs"
