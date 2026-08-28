# frozen_string_literal: true

module Api
  module V1
    class BaseController < ActionController::Base
      # Herda de ActionController::Base, e não de ApplicationController —
      # por isso a regra de primeiro acesso precisa ser incluída
      # explicitamente aqui. Era justamente essa divergência de herança
      # que deixava a API inteira fora do portão da senha provisória.
      include ExigeTrocaDeSenha

      # Esta API autentica por sessão (Devise), não por token, e por isso
      # tem o token CSRF desativado (skip_before_action abaixo) — normal
      # para uma API JSON pura. O problema é que, sem a checagem de
      # Content-Type abaixo, ela continuava aceitando corpo
      # application/x-www-form-urlencoded normalmente, o que reabria o
      # vetor clássico de CSRF que o token deveria fechar: um <form> HTML
      # comum em outro site consegue enviar Content-Type:
      # application/x-www-form-urlencoded usando o cookie de sessão já
      # autenticado do usuário (é um dos 3 tipos "simples" que um <form>
      # pode enviar sem JavaScript), mas nunca application/json. Só
      # JavaScript com fetch/XHR consegue definir esse header — e isso já
      # esbarra na política de mesma origem do navegador, já que esta
      # aplicação não configura CORS para outras origens.
      #
      # Em outras palavras: exigir Content-Type: application/json abaixo é
      # o que de fato torna seguro pular o token CSRF aqui — o mesmo
      # raciocínio por trás de ActionController::API não incluir proteção
      # CSRF por padrão.
      skip_before_action :verify_authenticity_token
      before_action :authenticate_user!
      before_action :require_json_content_type!, unless: -> { request.get? || request.head? }

      rescue_from CanCan::AccessDenied do |exception|
        render json: { error: exception.message }, status: :forbidden
      end

      rescue_from ActiveRecord::RecordNotFound do |exception|
        render json: { error: exception.message }, status: :not_found
      end

      private

      def require_json_content_type!
        return if request.content_type == 'application/json'

        render json: { error: 'Content-Type deve ser application/json.' }, status: :unsupported_media_type
      end

      # 403 e não redirect: a tela web manda o usuário pra /definir-senha,
      # mas um cliente de API precisa de uma resposta que ele consiga ler.
      def responder_troca_de_senha_exigida
        render json: {
          error: 'Defina a sua senha antes de usar a API. Acesse /definir-senha na interface web.'
        }, status: :forbidden
      end
    end
  end
end
