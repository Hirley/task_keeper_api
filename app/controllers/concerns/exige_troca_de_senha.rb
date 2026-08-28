# frozen_string_literal: true

# Primeiro acesso: quem ainda está com a senha provisória cadastrada pelo
# líder/admin (User#must_change_password) não usa mais nada até definir a
# própria senha — ver DefinirSenhaController.
#
# Isto era um before_action só do ApplicationController, e por isso valia
# só na tela web: Api::V1::BaseController herda de ActionController::Base,
# não de ApplicationController, então a API inteira ficava de fora. Um
# usuário recém-cadastrado ficava barrado em toda página do site e, ao
# mesmo tempo, criava demandas e listava usuários normalmente pela API —
# com uma senha que quem a cadastrou também conhece.
#
# Virou concern justamente pra que a regra não dependa de quem herda de
# quem: uma terceira interface que apareça inclui isto e implementa a
# resposta. O que muda entre as duas é só COMO recusar (redirect na web,
# JSON na API); a condição é a mesma e mora aqui.
module ExigeTrocaDeSenha
  extend ActiveSupport::Concern

  included do
    before_action :exigir_troca_de_senha!
  end

  private

  def exigir_troca_de_senha!
    return unless troca_de_senha_pendente?

    responder_troca_de_senha_exigida
  end

  def troca_de_senha_pendente?
    return false unless user_signed_in?
    # As telas do próprio Devise escapam — acima de tudo o logout, senão
    # quem está preso nesse estado não conseguiria nem sair.
    return false if devise_controller?
    return false if controller_name == 'definir_senha'

    current_user.must_change_password?
  end

  # Cada interface implementa a sua. Sem default de propósito: um
  # controller que inclua o concern e esqueça disto quebra alto, em vez
  # de deixar passar silenciosamente — que foi exatamente o modo de
  # falha que abriu o buraco na API.
  def responder_troca_de_senha_exigida
    raise NotImplementedError, "#{self.class} precisa implementar #responder_troca_de_senha_exigida"
  end
end
