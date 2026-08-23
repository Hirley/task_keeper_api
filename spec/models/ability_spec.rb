# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Ability, type: :model do
  subject(:ability) { described_class.new(user) }

  let(:demanda) { create(:demanda) }
  let(:outro_usuario) { create(:user, :executor) }

  context 'quando o usuário é executor' do
    let(:user) { create(:user, :executor) }

    it { is_expected.to be_able_to(:create, Demanda) }
    it { is_expected.to be_able_to(:read, demanda) }
    it { is_expected.not_to be_able_to(:update, demanda) }
    it { is_expected.not_to be_able_to(:destroy, demanda) }
    it { is_expected.not_to be_able_to(:manage, User) }
    it { is_expected.not_to be_able_to(:create, User) }
    it { is_expected.not_to be_able_to(:destroy, outro_usuario) }
  end

  context 'quando o usuário é líder' do
    let(:user) { create(:user, :lider) }

    it { is_expected.to be_able_to(:create, Demanda) }
    it { is_expected.to be_able_to(:read, demanda) }
    it { is_expected.to be_able_to(:update, demanda) }
    it { is_expected.to be_able_to(:destroy, demanda) }
    it { is_expected.to be_able_to(:manage, User) }
    it { is_expected.to be_able_to(:destroy, outro_usuario) }

    # Webhooks (Chat ID do Telegram e WebhookSubscription) são exclusivos
    # do admin — ver app/models/ability.rb.
    it { is_expected.not_to be_able_to(:manage, WebhookSubscription) }
  end

  context 'quando o usuário é admin' do
    let(:user) { create(:user, :admin) }

    it { is_expected.to be_able_to(:create, Demanda) }
    it { is_expected.to be_able_to(:read, demanda) }
    it { is_expected.to be_able_to(:update, demanda) }
    it { is_expected.to be_able_to(:destroy, demanda) }
    it { is_expected.to be_able_to(:manage, User) }
    it { is_expected.to be_able_to(:destroy, outro_usuario) }
    it { is_expected.to be_able_to(:manage, WebhookSubscription) }
  end

  context 'quando não há usuário autenticado' do
    let(:user) { nil }

    it { is_expected.not_to be_able_to(:create, Demanda) }
    it { is_expected.not_to be_able_to(:read, demanda) }
  end
end
