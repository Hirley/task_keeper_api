# frozen_string_literal: true

class ApplicationController < ActionController::Base
  include Paginatable
  # O before_action vem de dentro do concern, então roda antes do
  # authenticate_user! abaixo — não faz diferença, porque
  # #troca_de_senha_pendente? já sai cedo pra quem não está logado.
  include ExigeTrocaDeSenha

  before_action :authenticate_user!

  rescue_from CanCan::AccessDenied do |exception|
    respond_to do |format|
      format.html { redirect_to root_path, alert: exception.message }
      format.json { render json: { error: exception.message }, status: :forbidden }
      format.any  { redirect_to root_path, alert: exception.message }
    end
  end

  private

  # Como a tela web recusa quem ainda está com a senha provisória — a
  # condição em si mora em ExigeTrocaDeSenha, compartilhada com a API.
  def responder_troca_de_senha_exigida
    redirect_to edit_definir_senha_path
  end
end
