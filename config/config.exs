import Config

config :hephaestus_ecto, ecto_repos: [HephaestusEcto.TestRepo]

import_config "#{config_env()}.exs"
