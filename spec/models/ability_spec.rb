require "rails_helper"

RSpec.describe Ability, type: :model do
  subject(:ability) { described_class.new(user) }

  let(:demanda) { create(:demanda) }

  context "quando o usuário é executor" do
    let(:user) { create(:user, :executor) }

    it { is_expected.to be_able_to(:create, Demanda) }
    it { is_expected.to be_able_to(:read, demanda) }
    it { is_expected.not_to be_able_to(:update, demanda) }
    it { is_expected.not_to be_able_to(:destroy, demanda) }
    it { is_expected.not_to be_able_to(:manage, User) }
    it { is_expected.not_to be_able_to(:create, User) }
  end

  context "quando o usuário é líder" do
    let(:user) { create(:user, :lider) }

    it { is_expected.to be_able_to(:create, Demanda) }
    it { is_expected.to be_able_to(:read, demanda) }
    it { is_expected.to be_able_to(:update, demanda) }
    it { is_expected.to be_able_to(:destroy, demanda) }
    it { is_expected.to be_able_to(:manage, User) }
  end

  context "quando não há usuário autenticado" do
    let(:user) { nil }

    it { is_expected.not_to be_able_to(:create, Demanda) }
    it { is_expected.not_to be_able_to(:read, demanda) }
  end
end
