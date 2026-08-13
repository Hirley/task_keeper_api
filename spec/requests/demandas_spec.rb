require "rails_helper"

RSpec.describe "Demandas (tela web)", type: :request do
  let(:lider) { create(:user, :lider) }
  let(:executor) { create(:user, :executor) }

  describe "GET /demandas" do
    it "mostra o botão de nova demanda mas esconde as ações de editar/excluir para o executor" do
      create(:demanda, user: lider)
      sign_in executor

      get "/demandas"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Nova demanda")
      expect(response.body).not_to include("Editar")
      expect(response.body).not_to include("Excluir")
    end

    it "mostra as ações de editar e excluir para o líder" do
      create(:demanda, user: executor)
      sign_in lider

      get "/demandas"

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Nova demanda")
      expect(response.body).to include("Editar")
      expect(response.body).to include("Excluir")
    end
  end

  describe "GET /demandas/new" do
    it "permite que um executor acesse o formulário de criação" do
      sign_in executor
      get "/demandas/new"
      expect(response).to have_http_status(:ok)
    end

    it "permite que um líder acesse o formulário de criação" do
      sign_in lider
      get "/demandas/new"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /demandas" do
    it "permite que um executor crie uma demanda pela tela" do
      sign_in executor
      expect {
        post "/demandas", params: { demanda: { title: "Nova demanda web" } }
      }.to change(Demanda, :count).by(1)
      expect(response).to redirect_to(demandas_path)
    end

    it "permite que um líder crie uma demanda pela tela" do
      sign_in lider
      expect {
        post "/demandas", params: { demanda: { title: "Nova demanda web" } }
      }.to change(Demanda, :count).by(1)
      expect(response).to redirect_to(demandas_path)
    end
  end

  describe "GET /demandas/:id/edit" do
    let!(:demanda) { create(:demanda, user: lider) }

    it "bloqueia um executor" do
      sign_in executor
      get "/demandas/#{demanda.id}/edit"
      expect(response).to redirect_to(root_path)
    end

    it "permite um líder" do
      sign_in lider
      get "/demandas/#{demanda.id}/edit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /demandas/:id" do
    let!(:demanda) { create(:demanda, user: lider) }

    it "bloqueia um executor e não altera a demanda" do
      sign_in executor
      patch "/demandas/#{demanda.id}", params: { demanda: { title: "Alterada" } }
      expect(response).to redirect_to(root_path)
      expect(demanda.reload.title).not_to eq("Alterada")
    end

    it "permite que um líder atualize a demanda" do
      sign_in lider
      patch "/demandas/#{demanda.id}", params: { demanda: { title: "Alterada" } }
      expect(response).to redirect_to(demandas_path)
      expect(demanda.reload.title).to eq("Alterada")
    end
  end

  describe "DELETE /demandas/:id" do
    let!(:demanda) { create(:demanda, user: lider) }

    it "bloqueia um executor e não exclui a demanda" do
      sign_in executor
      expect {
        delete "/demandas/#{demanda.id}"
      }.not_to change(Demanda, :count)
      expect(response).to redirect_to(root_path)
    end

    it "permite que um líder exclua a demanda" do
      sign_in lider
      expect {
        delete "/demandas/#{demanda.id}"
      }.to change(Demanda, :count).by(-1)
      expect(response).to redirect_to(demandas_path)
    end
  end
end
