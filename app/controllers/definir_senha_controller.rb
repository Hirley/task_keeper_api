# frozen_string_literal: true

# Primeiro acesso: quem loga com a senha provisória cadastrada pelo
# líder/admin é trazido pra cá por
# ApplicationController#exigir_troca_de_senha! antes de conseguir usar
# qualquer outra tela. Não pede a senha atual (o usuário acabou de
# autenticar com ela) — só a nova senha + confirmação, iguais ao restante
# do app (ver Devise::Models::Validatable).
class DefinirSenhaController < ApplicationController
  def edit
    @user = current_user
  end

  def update
    @user = current_user

    if @user.update(senha_params.merge(must_change_password: false))
      # Trocar a senha muda o "salt" de autenticação do Devise
      # (authenticatable_salt), o que invalidaria a sessão atual na
      # próxima requisição — bypass_sign_in atualiza a sessão com o novo
      # salt, sem precisar pedir a senha de novo (ver
      # Devise::Controllers::SignInOut).
      bypass_sign_in(@user)
      # tour_pronto: além do #tk-tour-autostart disparar sozinho (ver
      # app/views/dashboard/index.html.haml), deixa um link explícito no
      # próprio flash — chama TkGuideTour.start() direto (ver
      # app/javascript/application.js), sem depender de "turbo:load"
      # disparar depois desse redirect.
      redirect_to root_path, notice: 'Senha definida com sucesso.', flash: { tour_pronto: true }
    else
      render :edit, status: :unprocessable_content
    end
  end

  private

  def senha_params
    params.require(:user).permit(:password, :password_confirmation)
  end
end
