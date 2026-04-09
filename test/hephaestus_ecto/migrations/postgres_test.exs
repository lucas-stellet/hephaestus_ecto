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

  describe "migrated_version/1" do
    test "reads table comments from a non-public prefix", %{prefix: prefix} do
      try do
        TestRepo.query!("CREATE TABLE #{prefix}.workflow_instances (id uuid PRIMARY KEY)")
        TestRepo.query!("COMMENT ON TABLE #{prefix}.workflow_instances IS '7'")

        assert Postgres.migrated_version(repo: TestRepo, prefix: prefix) == 7
      after
        TestRepo.query!("DROP SCHEMA IF EXISTS #{prefix} CASCADE")
      end
    end

    test "returns 0 when table does not exist", %{prefix: prefix} do
      try do
        assert Postgres.migrated_version(repo: TestRepo, prefix: prefix) == 0
      after
        TestRepo.query!("DROP SCHEMA IF EXISTS #{prefix} CASCADE")
      end
    end

    test "returns correct version on public schema" do
      version = Postgres.migrated_version(repo: TestRepo, prefix: "public")
      assert version == Postgres.current_version()
    end

    test "returns 0 when comment is NULL on public schema" do
      TestRepo.query!("COMMENT ON TABLE workflow_instances IS NULL", [], log: false)

      try do
        assert 0 = Postgres.migrated_version(repo: TestRepo, prefix: "public")
      after
        TestRepo.query!(
          "COMMENT ON TABLE \"public\".workflow_instances IS '#{Postgres.current_version()}'",
          [],
          log: false
        )
      end
    end
  end

  describe "up/1 no-op" do
    test "returns :ok when already at current version" do
      assert :ok = Postgres.up(repo: TestRepo, prefix: "public")
    end
  end

  describe "down/1" do
    test "returns :ok when target version is above current version", %{prefix: prefix} do
      try do
        assert :ok = Postgres.down(repo: TestRepo, prefix: prefix, version: 2)
      after
        TestRepo.query!("DROP SCHEMA IF EXISTS #{prefix} CASCADE")
      end
    end
  end

  describe "prefix validation" do
    test "rejects invalid prefix" do
      assert_raise ArgumentError, fn ->
        Postgres.up(prefix: "Robert'; DROP TABLE --", repo: TestRepo)
      end
    end

    test "rejects prefix with special characters" do
      assert_raise ArgumentError, fn ->
        Postgres.up(prefix: "my-prefix", repo: TestRepo)
      end
    end
  end
end
