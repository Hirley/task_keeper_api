require "rails_helper"

RSpec.describe "Usuários (tela web de Acessos)", type: :request do
  let(:lider) { create(:user, :lider) }
  let(:executor) { create(:user, :executor) }

  let(:novo_usuario_params) do
    {
      user: {
        name: "Novo Usuário",
        email: "novo.acesso@task-keeper.local",
        password: "senha123456",
        password_confirmation: "senha123456",
        role: "executor"
      }
    }
  end

  describe "GET /users" do
    it "bloqueia um executor" do
      sign_in executor
      get "/users"
      expect(response).to redirect_to(root_path)
    end

    it "permite que um líder veja a lista de acessos" do
      sign_in lider
      get "/users"
      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Acessos")
    end

    it "filtra por nome/e-mail via o formulário de busca" do
      create(:user, name: "Ana Souza", email: "ana@task-keeper.local")
      create(:user, name: "Bruno Lima", email: "bruno@task-keeper.local")
      sign_in lider

      get "/users", params: { q: "Ana" }

      expect(response.body).to include("Ana Souza")
      expect(response.body).not_to include("Bruno Lima")
    end

    it "filtra por permissão" do
      outra_lideranca = create(:user, :lider, name: "Outra Liderança")
      outro_executor = create(:user, :executor, name: "Outro Executor")
      sign_in lider

      get "/users", params: { role: "lider" }

      expect(response.body).to include("Outra Liderança")
      expect(response.body).not_to include("Outro Executor")
    end
  end

  describe "GET /users/new" do
    it "bloqueia um executor" do
      sign_in executor
      get "/users/new"
      expect(response).to redirect_to(root_path)
    end

    it "permite que um líder acesse o formulário de cadastro" do
      sign_in lider
      get "/users/new"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /users" do
    it "bloqueia um executor e não cria o usuário" do
      sign_in executor
      expect {
        post "/users", params: novo_usuario_params
      }.not_to change(User, :count)
      expect(response).to redirect_to(root_path)
    end

    it "permite que um líder cadastre um novo usuário com a permissão escolhida" do
      sign_in lider
      expect {
        post "/users", params: novo_usuario_params
      }.to change(User, :count).by(1)
      expect(response).to redirect_to(users_path)
      expect(User.last.executor?).to be true
    end
  end

  describe "GET /users/:id/edit" do
    let!(:outro_usuario) { create(:user, :executor) }

    it "bloqueia um executor" do
      sign_in executor
      get "/users/#{outro_usuario.id}/edit"
      expect(response).to redirect_to(root_path)
    end

    it "permite que um líder acesse a edição de permissões" do
      sign_in lider
      get "/users/#{outro_usuario.id}/edit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe "PATCH /users/:id" do
    let!(:outro_usuario) { create(:user, :executor) }

    it "bloqueia um executor e não altera a permissão" do
      sign_in executor
      patch "/users/#{outro_usuario.id}", params: { user: { role: "lider" } }
      expect(response).to redirect_to(root_path)
      expect(outro_usuario.reload.executor?).to be true
    end

    it "permite que um líder promova outro usuário a líder" do
      sign_in lider
      patch "/users/#{outro_usuario.id}", params: { user: { role: "lider" } }
      expect(response).to redirect_to(users_path)
      expect(outro_usuario.reload.lider?).to be true
    end

    it "permite que um líder rebaixe outro líder para executor" do
      outro_lider = create(:user, :lider)
      sign_in lider
      patch "/users/#{outro_lider.id}", params: { user: { role: "executor" } }
      expect(outro_lider.reload.executor?).to be true
    end
  end

  describe "DELETE /users/:id" do
    let!(:outro_usuario) { create(:user, :executor) }

    it "bloqueia um executor e não exclui o usuário" do
      sign_in executor
      expect {
        delete "/users/#{outro_usuario.id}"
      }.not_to change(User, :count)
      expect(response).to redirect_to(root_path)
    end

    it "permite que um líder exclua outro usuário" do
      sign_in lider
      expect {
        delete "/users/#{outro_usuario.id}"
      }.to change(User, :count).by(-1)
      expect(response).to redirect_to(users_path)
    end

    it "impede que o líder exclua o próprio usuário" do
      sign_in lider
      expect {
        delete "/users/#{lider.id}"
      }.not_to change(User, :count)
      expect(response).to redirect_to(users_path)
      expect(flash[:alert]).to match(/não pode excluir o seu próprio usuário/i)
    end

    it "impede excluir um usuário que já tem demandas cadastradas" do
      create(:demanda, user: outro_usuario)
      sign_in lider

      expect {
        delete "/users/#{outro_usuario.id}"
      }.not_to change(User, :count)
      expect(response).to redirect_to(users_path)
      expect(flash[:alert]).to match(/demandas cadastradas/i)
    end
  end
end
