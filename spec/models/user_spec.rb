# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  it { is_expected.to define_enum_for(:role).with_values(executor: 0, lider: 1, admin: 2) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to have_many(:demandas) }
  it { is_expected.to have_many(:webhook_subscriptions) }

  it 'é válido com atributos válidos' do
    expect(user).to be_valid
  end

  describe '#telegram_chat_id' do
    it 'é válido em branco (campo opcional)' do
      expect(build(:user, telegram_chat_id: nil)).to be_valid
      expect(build(:user, telegram_chat_id: '')).to be_valid
    end

    it 'aceita um chat_id numérico' do
      expect(build(:user, telegram_chat_id: '123456789')).to be_valid
    end

    it 'aceita um chat_id negativo (chats de grupo no Telegram usam id negativo)' do
      expect(build(:user, telegram_chat_id: '-100123456789')).to be_valid
    end

    it 'rejeita um chat_id não numérico' do
      user = build(:user, telegram_chat_id: '@meu_usuario')
      expect(user).not_to be_valid
      expect(user.errors[:telegram_chat_id]).to be_present
    end
  end

  # Ver config/initializers/devise.rb: o mínimo é maior que o default do
  # Devise porque a primeira senha de todo usuário é escolhida por um
  # líder/admin, não pelo dono da conta.
  describe 'tamanho mínimo da senha' do
    it 'rejeita uma senha mais curta que o mínimo configurado' do
      curta = 'a' * (Devise.password_length.min - 1)
      user = build(:user, password: curta, password_confirmation: curta)

      expect(user).not_to be_valid
      expect(user.errors[:password]).to be_present
    end

    it 'aceita uma senha no tamanho mínimo' do
      no_limite = 'a' * Devise.password_length.min

      expect(build(:user, password: no_limite, password_confirmation: no_limite)).to be_valid
    end

    it 'exige pelo menos 12 caracteres' do
      expect(Devise.password_length.min).to be >= 12
    end
  end

  # Ver User#validar_atribuicao_de_papel. O papel admin é a única coisa
  # que separa admin de líder (app/models/ability.rb), e o líder gerencia
  # usuários — sem estas regras ele se promovia a admin sozinho.
  describe 'atribuição de papel' do
    let(:lider) { create(:user, :lider) }
    let(:admin) { create(:user, :admin) }
    let(:alvo) { create(:user, :executor) }

    def alterar(usuario, para:, por:)
      usuario.ator = por
      usuario.role = para
      usuario
    end

    context 'quando quem altera é líder' do
      it 'não deixa promover outro usuário a admin' do
        expect(alterar(alvo, para: 'admin', por: lider)).not_to be_valid
      end

      it 'não deixa promover a si mesmo a admin' do
        expect(alterar(lider, para: 'admin', por: lider)).not_to be_valid
      end

      it 'não deixa rebaixar um admin' do
        expect(alterar(admin, para: 'lider', por: lider)).not_to be_valid
      end

      it 'continua deixando promover outro usuário a líder' do
        expect(alterar(alvo, para: 'lider', por: lider)).to be_valid
      end

      it 'continua deixando rebaixar outro líder para executor' do
        outro_lider = create(:user, :lider)

        expect(alterar(outro_lider, para: 'executor', por: lider)).to be_valid
      end
    end

    context 'quando quem altera é admin' do
      it 'deixa promover outro usuário a admin' do
        expect(alterar(alvo, para: 'admin', por: admin)).to be_valid
      end

      it 'deixa rebaixar outro admin' do
        outro_admin = create(:user, :admin)

        expect(alterar(outro_admin, para: 'lider', por: admin)).to be_valid
      end

      # Impede o último admin de se rebaixar e deixar os webhooks sem
      # ninguém que possa gerenciá-los.
      it 'não deixa alterar o próprio papel' do
        expect(alterar(admin, para: 'lider', por: admin)).not_to be_valid
      end
    end

    it 'não impede editar os próprios dados quando o papel não muda' do
      lider.ator = lider
      lider.name = 'Outro Nome'

      expect(lider).to be_valid
    end

    it 'não impede um líder de editar o nome de um admin (o papel não muda)' do
      admin.ator = lider
      admin.name = 'Outro Nome'

      expect(admin).to be_valid
    end

    # A invariante é fail-CLOSED: o esquecimento vira erro visível, não
    # brecha silenciosa. Antes esta validação começava com
    # `return if ator.blank?`, e valia só porque os controllers de hoje
    # lembram de preencher o ator — qualquer caminho novo passava direto.
    it 'recusa a mudança de papel quando ninguém informou o ator' do
      alvo.role = 'admin'

      expect(alvo).not_to be_valid
      expect(alvo.errors[:role].join).to include('quem está fazendo a alteração')
    end

    it 'recusa também a criação de um usuário com papel, sem ator' do
      novo = build(:user, role: :admin, ator_dispensado: false)

      expect(novo).not_to be_valid
    end

    # A saída declarada, para os poucos lugares legítimos: seeds, console
    # e a própria factory desta suíte.
    it 'permite quando o chamador declara que está fora de uma requisição' do
      alvo.ator_dispensado = true
      alvo.role = 'admin'

      expect(alvo).to be_valid
    end

    # Sem esta guarda, exigir ator em toda escrita quebraria qualquer
    # atualização de usuário feita fora de requisição (rake task, job) que
    # não tem nada a ver com papel.
    it 'não exige ator quando o papel não está mudando' do
      alvo.name = 'Outro Nome'

      expect(alvo).to be_valid
    end

    it 'explica o motivo na mensagem de erro' do
      alterar(alvo, para: 'admin', por: lider).valid?

      expect(alvo.errors[:role].join).to include('admin')
    end
  end

  describe '#must_change_password' do
    it 'é true por padrão (senha provisória cadastrada pelo líder/admin, ver a migration)' do
      expect(described_class.new.must_change_password?).to be true
    end
  end

  describe '#reset_password' do
    it 'marca must_change_password como false ao redefinir a senha' do
      user = create(:user, :primeiro_acesso)

      user.reset_password('novaSenha123', 'novaSenha123')

      expect(user.reload.must_change_password?).to be false
    end

    it 'continua trocando a senha normalmente (comportamento original do Devise)' do
      user = create(:user, :primeiro_acesso)

      user.reset_password('novaSenha123', 'novaSenha123')

      expect(user.reload.valid_password?('novaSenha123')).to be true
    end

    it 'não salva quando a confirmação não bate, e mantém must_change_password como estava' do
      user = create(:user, :primeiro_acesso)

      result = user.reset_password('novaSenha123', 'outraSenha')

      expect(result).to be false
      expect(user.reload.must_change_password?).to be true
    end
  end

  describe '#lider?, #executor? e #admin?' do
    it 'identifica um usuário líder' do
      lider = build(:user, :lider)
      expect(lider.lider?).to be true
      expect(lider.executor?).to be false
      expect(lider.admin?).to be false
    end

    it 'identifica um usuário executor' do
      executor = build(:user, :executor)
      expect(executor.executor?).to be true
      expect(executor.lider?).to be false
      expect(executor.admin?).to be false
    end

    it 'identifica um usuário admin' do
      admin = build(:user, :admin)
      expect(admin.admin?).to be true
      expect(admin.lider?).to be false
      expect(admin.executor?).to be false
    end
  end

  describe '#lider_ou_admin?' do
    it 'é true pra líder e admin, false pra executor' do
      expect(build(:user, :lider).lider_ou_admin?).to be true
      expect(build(:user, :admin).lider_ou_admin?).to be true
      expect(build(:user, :executor).lider_ou_admin?).to be false
    end
  end

  describe '#role_label' do
    it 'devolve o nome do papel em português, com acento' do
      expect(build(:user, :lider).role_label).to eq('líder')
      expect(build(:user, :executor).role_label).to eq('executor')
      expect(build(:user, :admin).role_label).to eq('admin')
    end
  end

  describe '#role_badge_class' do
    it 'devolve a classe CSS do badge de cada papel' do
      expect(build(:user, :lider).role_badge_class).to eq('tk-badge-lider')
      expect(build(:user, :executor).role_badge_class).to eq('tk-badge-executor')
      expect(build(:user, :admin).role_badge_class).to eq('tk-badge-admin')
    end
  end
end
