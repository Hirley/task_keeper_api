# frozen_string_literal: true

require 'rails_helper'

# Regressão para o bug do "primeiro login": com rotas preguiçosas e sem
# eager load, Devise.configure_warden! só rodava dentro da primeira
# requisição — depois de o Warden já ter copiado uma config sem
# estratégia nenhuma. O efeito era um POST /users/sign_in com credenciais
# válidas respondendo 422, mas apenas na primeira requisição do processo.
# A explicação completa está em config/initializers/devise.rb.
#
# O exemplo não faz login de propósito: um teste de requisição só
# reproduziria a falha se fosse o primeiro do processo, e essa dependência
# de ordem é justamente o que manteve o bug invisível por tanto tempo (ele
# só aparecia quando a ordem aleatória do RSpec colaborava). O que se
# verifica aqui é a causa, não o sintoma — e o retrato usado vem do
# before(:suite) do rails_helper, tirado antes de qualquer exemplo.
RSpec.describe Devise do
  it 'registra as estratégias do Warden antes da primeira requisição' do
    estrategias = RSpec.configuration.estrategias_do_warden_no_boot

    expect(estrategias).to include(:user),
                           'O Warden subiu sem estratégia nenhuma para :user, então o primeiro POST ' \
                           '/users/sign_in do processo vai recusar credenciais válidas. Provavelmente ' \
                           'o after_initialize no fim de config/initializers/devise.rb foi removido.'
    expect(estrategias[:user]).to include(:database_authenticatable)
  end
end
