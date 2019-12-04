defmodule Reaper.MigrationsTest do
  use ExUnit.Case
  use Divo, auto_start: false

  import SmartCity.TestHelper
  alias SmartCity.TestDataGenerator, as: TDG

  @instance Reaper.Application.instance()

  describe "quantum job migration" do
    @tag :capture_log

    setup do
      Application.ensure_all_started(:redix)

      {:ok, redix} = Redix.start_link(host: Application.get_env(:redix, :host), name: :redix)
      {:ok, scheduler} = Reaper.Scheduler.Supervisor.start_link([])
      Process.unlink(redix)
      Process.unlink(scheduler)

      on_exit(fn ->
        kill(scheduler)
        kill(redix)
        Application.stop(:reaper)
      end)

      %{redix: redix, scheduler: scheduler}
    end

    test "should pre-pend the brook instance to all scheduled quantum jobs", %{redix: redix, scheduler: scheduler} do
      Application.ensure_all_started(:redix)

      dataset_id = String.to_atom("old-cron-schedule")
      create_job(dataset_id)

      kill(scheduler)
      kill(redix)

      Application.ensure_all_started(:reaper)

      Process.sleep(10_000)

      eventually(fn ->
        job = Reaper.Scheduler.find_job(dataset_id)
        assert not is_nil(job)
        assert job.task == {Brook.Event, :send, [@instance, "migration:test", :reaper, dataset_id]}
      end)
    end

    @tag :capture_log
    test "should add the topLevelSelector field to the struct of all scheduled quantum jobs", %{
      redix: redix,
      scheduler: scheduler
    } do
      old_dataset = %{
        __struct__: SmartCity.Dataset,
        id: "123",
        business: %{
          __struct__: SmartCity.Dataset.Business,
          authorEmail: nil,
          authorName: nil,
          categories: nil,
          conformsToUri: nil,
          contactEmail: nil,
          contactName: nil,
          dataTitle: nil,
          describedByMimeType: nil,
          describedByUrl: nil,
          description: nil,
          homepage: nil,
          issuedDate: nil,
          keywords: nil,
          language: nil,
          license: nil,
          modifiedDate: nil,
          orgTitle: nil,
          parentDataset: nil,
          publishFrequency: nil,
          referenceUrls: nil,
          rights: nil,
          spatial: nil,
          temporal: nil
        },
        technical: %{
          __struct__: SmartCity.Dataset.Technical,
          allow_duplicates: true,
          authHeaders: %{},
          authUrl: nil,
          cadence: "never",
          credentials: false,
          dataName: nil,
          orgId: nil,
          orgName: nil,
          private: true,
          protocol: nil,
          schema: [],
          sourceFormat: nil,
          sourceHeaders: %{},
          sourceQueryParams: %{},
          sourceType: "remote",
          sourceUrl: nil,
          systemName: nil,
          topLevelSelector: nil
        }
      }

      expected_dataset = old_dataset |> Map.put(:topLevelSelector, nil)

      create_job_with_dataset(old_dataset)

      IO.inspect(old_dataset, label: "OLLLLLD")

      kill(scheduler)
      kill(redix)

      Application.ensure_all_started(:reaper)

      Process.sleep(10_000)

      eventually(fn ->
        # assert false == true
        job = Reaper.Scheduler.find_job(String.to_atom(old_dataset.id))
        assert not is_nil(job), "job should have been found"
        assert job.task == {Brook.Event, :send, [@instance, "migration:test", :reaper, expected_dataset]}
      end)
    end
  end

  defp create_job(dataset_id) do
    Reaper.Scheduler.new_job()
    |> Quantum.Job.set_name(dataset_id)
    |> Quantum.Job.set_schedule(Crontab.CronExpression.Parser.parse!("* * * * *"))
    |> Quantum.Job.set_task({Brook.Event, :send, ["migration:test", :reaper, dataset_id]})
    |> Reaper.Scheduler.add_job()
  end

  defp create_job_with_dataset(dataset) do
    Reaper.Scheduler.new_job()
    |> Quantum.Job.set_name(String.to_atom(dataset.id))
    |> Quantum.Job.set_schedule(Crontab.CronExpression.Parser.parse!("* * * * *"))
    |> Quantum.Job.set_task({Brook.Event, :send, [@instance, "migration:test", :reaper, dataset]})
    |> IO.inspect(label: "JOB IN TEST")
    |> Reaper.Scheduler.add_job()
  end

  describe "extractions migration" do
    @tag :capture_log

    setup do
      Application.ensure_all_started(:redix)
      Application.ensure_all_started(:faker)

      {:ok, redix} = Redix.start_link(host: Application.get_env(:redix, :host), name: :redix)
      Process.unlink(redix)

      {:ok, brook} =
        Brook.start_link(
          Application.get_env(:reaper, :brook)
          |> Keyword.delete(:driver)
          |> Keyword.put(:instance, @instance)
        )

      Process.unlink(brook)

      on_exit(fn ->
        kill(redix)
        kill(brook)
        Application.stop(:reaper)
        Application.stop(:faker)
      end)

      %{brook: brook, redix: redix}
    end

    test "should migrate extractions and enable all of them", %{brook: brook, redix: redix} do
      extraction_without_enabled_flag_id = 1
      extraction_with_enabled_true_id = 2
      extraction_with_enabled_false_id = 3
      invalid_extraction_id = 4

      Brook.Test.with_event(
        @instance,
        Brook.Event.new(type: "reaper_config:migration", author: "migration", data: %{}),
        fn ->
          Brook.ViewState.merge(:extractions, extraction_without_enabled_flag_id, %{
            dataset: TDG.create_dataset(id: extraction_without_enabled_flag_id)
          })

          Brook.ViewState.merge(:extractions, extraction_with_enabled_true_id, %{
            dataset: TDG.create_dataset(id: extraction_with_enabled_true_id),
            enabled: true
          })

          Brook.ViewState.merge(:extractions, extraction_with_enabled_false_id, %{
            dataset: TDG.create_dataset(id: extraction_with_enabled_false_id),
            enabled: false
          })

          Brook.ViewState.merge(:extractions, invalid_extraction_id, %{})
        end
      )

      kill(brook)
      kill(redix)

      Application.ensure_all_started(:reaper)

      Process.sleep(10_000)

      eventually(fn ->
        assert true == Brook.get!(@instance, :extractions, extraction_without_enabled_flag_id)["enabled"]
        assert true == Brook.get!(@instance, :extractions, extraction_with_enabled_true_id)["enabled"]
        assert false == Brook.get!(@instance, :extractions, extraction_with_enabled_false_id)["enabled"]
      end)
    end
  end

  defp kill(pid) do
    ref = Process.monitor(pid)
    Process.exit(pid, :shutdown)
    assert_receive {:DOWN, ^ref, _, _, _}, 5_000
  end
end
