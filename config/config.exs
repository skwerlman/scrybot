import Config

# NOTE: these intents must be enabled in the discord application manager!
privileged_intents = [
  :message_content
]

config :nostrum, :streamlink, false

# See https://kraigie.github.io/nostrum/gateway-intents.html for info about intents
config :nostrum,
  gateway_intents:
    [
      :guilds,
      :guild_webhooks,
      :guild_messages,
      :guild_message_reactions,
      :guild_message_typing,
      :direct_messages,
      :direct_message_reactions,
      :direct_message_typing
    ] ++ privileged_intents

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
  format: "$time $metadata[$level] $message\n",
  path: "log/scrybot.log"

config :logger, :default_logger,
  logger: :console,
  default_level: :info,
  level_config: [
    [application: :scrybot, module: Scrybot, level: :debug],
    [application: :lib_judge, module: Scrybot, level: :debug]
  ],
  format: "$time [$level] $message\n"

config :tesla, Tesla.Middleware.Telemetry, disable_legacy_event: true

config :tesla, :adapter, Tesla.Adapter.Mint

import_config "config.secret.exs"
