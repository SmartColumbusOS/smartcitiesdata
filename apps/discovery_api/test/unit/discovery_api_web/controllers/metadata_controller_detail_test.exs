defmodule DiscoveryApiWeb.MetadataController.DetailTest do
  use DiscoveryApiWeb.ConnCase
  use Placebo
  alias DiscoveryApi.Test.Helper
  alias DiscoveryApi.Data.Model
  alias DiscoveryApi.Schemas.Users
  alias DiscoveryApi.Schemas.Users.User

  @dataset_id "123"
  @org_id "456"
  @subject_id "bigbadbob"

  describe "fetch dataset detail" do
    test "retrieves dataset + organization from retriever when organization found", %{conn: conn} do
      schema = [
        %{
          description: "a number",
          name: "number",
          type: "integer",
          pii: "false",
          biased: "false",
          masked: "N/A",
          demographic: "None"
        },
        %{
          description: "a name",
          name: "name",
          type: "string",
          pii: "true",
          biased: "true",
          masked: "yes",
          demographic: "Other"
        }
      ]

      model =
        Helper.sample_model(%{id: @dataset_id})
        |> Map.put(:schema, schema)

      allow(Model.get(@dataset_id), return: model)

      actual = conn |> get("/api/v1/dataset/#{@dataset_id}") |> json_response(200)

      expected_schema = [
        %{"name" => "number", "type" => "integer", "description" => "a number"},
        %{"name" => "name", "type" => "string", "description" => "a name"}
      ]

      assert %{
               "id" => model.id,
               "name" => model.name,
               "title" => model.title,
               "description" => model.description,
               "keywords" => model.keywords,
               "organization" => %{
                 "name" => model.organizationDetails.orgName,
                 "title" => model.organizationDetails.orgTitle,
                 "image" => model.organizationDetails.logoUrl,
                 "description" => model.organizationDetails.description,
                 "homepage" => model.organizationDetails.homepage
               },
               "schema" => expected_schema,
               "sourceType" => model.sourceType,
               "sourceFormat" => model.sourceFormat,
               "sourceUrl" => model.sourceUrl,
               "lastUpdatedDate" => nil,
               "contactName" => model.contactName,
               "contactEmail" => model.contactEmail,
               "license" => model.license,
               "rights" => model.rights,
               "homepage" => model.homepage,
               "spatial" => model.spatial,
               "temporal" => model.temporal,
               "publishFrequency" => model.publishFrequency,
               "conformsToUri" => model.conformsToUri,
               "describedByUrl" => model.describedByUrl,
               "describedByMimeType" => model.describedByMimeType,
               "parentDataset" => model.parentDataset,
               "issuedDate" => model.issuedDate,
               "language" => model.language,
               "referenceUrls" => model.referenceUrls,
               "categories" => model.categories,
               "modified" => model.modifiedDate,
               "downloads" => model.downloads,
               "queries" => model.queries,
               "accessLevel" => model.accessLevel,
               "completeness" => model.completeness,
               "systemName" => model.systemName,
               "fileTypes" => model.fileTypes
             } == actual
    end

    test "returns 404", %{conn: conn} do
      expect(Model.get(any()), return: nil)

      conn |> get("/api/v1/dataset/xyz123") |> json_response(404)
    end
  end

  describe "fetch restricted dataset detail" do
    setup do
      model =
        Helper.sample_model(%{
          id: @dataset_id,
          private: true,
          lastUpdatedDate: nil,
          queries: 7,
          downloads: 9,
          organizationDetails: %{
            id: @org_id,
            orgName: "name",
            orgTitle: "whatever",
            description: "description",
            logoUrl: "logo url",
            homepage: "homepage"
          }
        })

      allow(Model.get(@dataset_id), return: model)

      :ok
    end

    test "does not retrieve a restricted dataset if the given user is not a member of the dataset's group",
         %{
           conn: conn
         } do
      allow(Users.get_user_with_organizations(@subject_id, :subject_id), return: {:ok, %User{organizations: []}})

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(@subject_id, %{}, token_type: "refresh")

      conn
      |> put_req_cookie(Helper.default_guardian_token_key(), token)
      |> get("/api/v1/dataset/#{@dataset_id}")
      |> json_response(404)
    end

    test "retrieves a restricted dataset if the given user has access to it, via cookie", %{
      conn: conn
    } do
      allow(Users.get_user_with_organizations(@subject_id, :subject_id), return: {:ok, %User{organizations: [%{id: @org_id}]}})

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(@subject_id, %{}, token_type: "refresh")

      conn
      |> put_req_cookie(Helper.default_guardian_token_key(), token)
      |> get("/api/v1/dataset/#{@dataset_id}")
      |> json_response(200)
    end

    test "retrieves a restricted dataset if the given user has access to it, via token", %{
      conn: conn
    } do
      allow(Users.get_user_with_organizations(@subject_id, :subject_id), return: {:ok, %User{organizations: [%{id: @org_id}]}})

      {:ok, token, _} = DiscoveryApi.Auth.Guardian.encode_and_sign(@subject_id, %{}, token_type: "refresh")

      conn
      |> put_req_header("authorization", "Bearer #{token}")
      |> get("/api/v1/dataset/#{@dataset_id}")
      |> json_response(200)
    end
  end
end
