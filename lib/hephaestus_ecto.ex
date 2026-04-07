defmodule HephaestusEcto do
  @moduledoc """
  Ecto/PostgreSQL storage adapter for Hephaestus workflow instances.

  ## Usage

      defmodule MyApp.Hephaestus do
        use Hephaestus,
          storage: {HephaestusEcto.Storage, repo: MyApp.Repo}
      end

  ## Setup

      $ mix hephaestus_ecto.gen.migration
      $ mix ecto.migrate
  """
end
