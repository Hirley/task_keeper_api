require "rails_helper"

RSpec.describe "Api::V1::Users", type: :request do
  let(:lider) { create(:user, :lider) }
  let(:executor) { create(:user, :executor) }

  let(:novo_usuario_params) do
    {
      user: {
        name: "Novo Usuário",
        email: "novo.usuario@task-keeper.local",
        password: "senha123456",
        password_confirmation: "senha123456",
        role: "executor"
      }
    }
  end

  describe "GET /api/v1/users" do
    it "bloqueia um executor com 403" do
      sign_in executor
      get "/api/v1/users"
      expect(response).to have_http_status(:forbidden)
    end

    it "permite que um líder liste os usuários" do
      sign_in lider
      get "/api/v1/users"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /api/v1/users" do
    it "bloqueia um executor com 403 e não cria o usuário" do
      sign_in executor
      expect {
        post "/api/v1/users", params: novo_usuario_params
      }.not_to change(User, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "permite que um líder cadastre um novo usuário" do
      sign_in lider
      expect {
        post "/api/v1/users", params: novo_usuario_params
      }.to change(User, :count).by(1)
      expect(response).to have_http_status(:created)
    end
  end

  describe "DELETE /api/v1/users/:id" do
    let!(:outro_usuario) { create(:user, :executor) }

    it "bloqueia um executor com 403 e não exclui o usuário" do
      sign_in executor
      expect {
        delete "/api/v1/users/#{outro_usuario.id}"
      }.not_to change(User, :count)
      expect(response).to have_http_status(:forbidden)
    end

    it "permite que um líder exclua outro usuário" do
      sign_in lider
      expect {
        delete "/api/v1/users/#{outro_usuario.id}"
      }.to change(User, :count).by(-1)
      expect(response).to have_http_status(:no_content)
    end

    it "impede que o líder exclua o próprio usuário" do
      sign_in lider
      expect {
        delete "/api/v1/users/#{lider.id}"
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end

    it "impede excluir um usuário que já tem demandas cadastradas" do
      create(:demanda, user: outro_usuario)
      sign_in lider

      expect {
        delete "/api/v1/users/#{outro_usuario.id}"
      }.not_to change(User, :count)
      expect(response).to have_http_status(:unprocessable_entity)
    end
  end
end
