{:ok, _} = HephaestusEcto.TestRepo.start_link()
ExUnit.start()
Ecto.Adapters.SQL.Sandbox.mode(HephaestusEcto.TestRepo, :manual)
