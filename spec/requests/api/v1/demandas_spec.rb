require "rails_helper"

RSpec.describe "Api::V1::Demandas", type: :request do
  let(:lider) { create(:user, :lider) }
  let(:executor) { create(:user, :executor) }

  describe "GET /api/v1/demandas" do
    before { create_list(:demanda, 2, user: executor) }

    it "exige autenticação" do
      get "/api/v1/demandas"
      expect(response).to have_http_status(:unauthorized).or have_http_status(:redirect)
    end

    it "lista demandas para um usuário autenticado" do
      sign_in executor
      get "/api/v1/demandas"
      expect(response).to have_http_status(:ok)
      expect(JSON.parse(response.body).size).to eq(2)
    end
  end

  describe "POST /api/v1/demandas" do
    it "permite que um executor crie uma demanda" do
      sign_in executor
      expect {
        post "/api/v1/demandas", params: { demanda: { title: "Nova demanda" } }
      }.to change(Demanda, :count).by(1)
      expect(response).to have_http_status(:created)
    end

    it "permite que um líder crie uma demanda" do
      sign_in lider
      expect {
        post "/api/v1/demandas", params: { demanda: { title: "Nova demanda" } }
      }.to change(Demanda, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  describe "PATCH /api/v1/demandas/:id" do
    let!(:demanda) { create(:demanda, user: lider) }

    it "bloqueia um executor com 403" do
      sign_in executor
      patch "/api/v1/demandas/#{demanda.id}", params: { demanda: { title: "Alterada" } }
      expect(response).to have_http_status(:forbidden)
      expect(demanda.reload.title).not_to eq("Alterada")
    end

    it "permite que um líder atualize a demanda" do
      sign_in lider
      patch "/api/v1/demandas/#{demanda.id}", params: { demanda: { title: "Alterada" } }
      expect(response).to have_http_status(:ok)
      expect(demanda.reload.title).to eq("Alterada")
    end
  end

  describe "DELETE /api/v1/demandas/:id" do
    let!(:demanda) { create(:demanda, user: lider) }

    it "bloqueia um executor com 403" do
      sign_in executor
      expect {
        delete "/api/v1/demandas/#{demanda.id}"
      }.not_to change(Demanda, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "permite que um líder exclua a demanda" do
      sign_in lider
      expect {
        delete "/api/v1/demandas/#{demanda.id}"
      }.to change(Demanda, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end
  end
end
