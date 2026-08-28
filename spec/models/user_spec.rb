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
