# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Paginatable

  before_action :authenticate_user!
  before_action :exigir_troca_de_senha!

  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.html { redirect_to root_path, alert: exception.message }
      format.json { render json: { error: exception.message }, status: :forbidden }
      format.any  { redirect_to root_path, alert: exception.message }
    end
  end

  private

  # Primeiro acesso: quem loga com a senha provisória cadastrada pelo
  # líder/admin (User#must_change_password) é barrado em qualquer outra
  # tela até passar por DefinirSenhaController e cadastrar a própria
  # senha. `devise_controller?` libera as telas do próprio Devise (acima
  # de tudo o logout — ver destroy_user_session_path no navbar — senão
  # quem está preso nesse estado não conseguiria nem deslogar).
  def exigir_troca_de_senha!
    return unless user_signed_in?
    return if devise_controller?
    return if controller_name == 'definir_senha'
    return unless current_user.must_change_password?

    redirect_to edit_definir_senha_path
  end
end
