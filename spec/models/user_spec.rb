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
