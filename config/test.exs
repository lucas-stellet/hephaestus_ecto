import Config

config :hephaestus_ecto, HephaestusEcto.TestRepo,
  username: "postgres",
  password: "postgres",
  hostname: "localhost",
  database: "hephaestus_ecto_test",
  pool: Ecto.Adapters.SQL.Sandbox
