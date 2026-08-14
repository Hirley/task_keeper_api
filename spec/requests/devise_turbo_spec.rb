require "rails_helper"

# Regressão: uma tentativa de login inválida devolvia HTTP 200 (o default
# do responder do Devise) pro POST em /users/sign_in. Como a tela de login
# usa Turbo Drive (gem turbo-rails), um POST de formulário que responde
# 200 sem redirecionar quebra o Turbo — o console do navegador acusa
# "Error: Form responses must redirect to another location" e a tela
# trava sem nenhum feedback visível pro usuário (nem a mensagem de erro
# aparece). Ver config/initializers/devise.rb (config.responder).
RSpec.describe "Compatibilidade do Devise com Turbo Drive", type: :request do
  let!(:user) { create(:user, password: "senha123456") }

  it "responde 422 (não 200) pra uma tentativa de login inválida" do
    post "/users/sign_in", params: { user: { email: user.email, password: "senha-errada" } }

    expect(response).to have_http_status(:unprocessable_entity)
  end

  it "responde com um redirect pro logout, não 200" do
    sign_in user
    delete destroy_user_session_path

    expect(response).to redirect_to(root_path)
  end
end
