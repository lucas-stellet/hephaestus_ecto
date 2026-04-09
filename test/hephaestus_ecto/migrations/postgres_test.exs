defmodule HephaestusEcto.Migrations.PostgresTest do
  use ExUnit.Case, async: false

  alias HephaestusEcto.Migrations.Postgres
  alias HephaestusEcto.TestRepo

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(TestRepo)

    prefix = "migration_test_#{System.unique_integer([:positive])}"
    TestRepo.query!("CREATE SCHEMA #{prefix}")

    %{prefix: prefix}
  end

  test "migrated_version/1 reads table comments from a non-public prefix", %{prefix: prefix} do
    try do
      TestRepo.query!("CREATE TABLE #{prefix}.workflow_instances (id uuid PRIMARY KEY)")
      TestRepo.query!("COMMENT ON TABLE #{prefix}.workflow_instances IS '7'")

      assert Postgres.migrated_version(repo: TestRepo, prefix: prefix) == 7
    after
      TestRepo.query!("DROP SCHEMA IF EXISTS #{prefix} CASCADE")
    end
  end

  test "down/1 returns :ok when target version is above current version", %{prefix: prefix} do
    try do
      assert :ok = Postgres.down(repo: TestRepo, prefix: prefix, version: 2)
    after
      TestRepo.query!("DROP SCHEMA IF EXISTS #{prefix} CASCADE")
    end
  end
end
