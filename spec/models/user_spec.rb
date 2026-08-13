require "rails_helper"

RSpec.describe User, type: :model do
  subject(:user) { build(:user) }

  it { is_expected.to define_enum_for(:role).with_values(executor: 0, lider: 1) }
  it { is_expected.to validate_presence_of(:name) }
  it { is_expected.to validate_presence_of(:email) }
  it { is_expected.to have_many(:demandas) }

  it "é válido com atributos válidos" do
    expect(user).to be_valid
  end

  describe "#telegram_chat_id" do
    it "é válido em branco (campo opcional)" do
      expect(build(:user, telegram_chat_id: nil)).to be_valid
      expect(build(:user, telegram_chat_id: "")).to be_valid
    end

    it "aceita um chat_id numérico" do
      expect(build(:user, telegram_chat_id: "123456789")).to be_valid
    end

    it "aceita um chat_id negativo (chats de grupo no Telegram usam id negativo)" do
      expect(build(:user, telegram_chat_id: "-100123456789")).to be_valid
    end

    it "rejeita um chat_id não numérico" do
      user = build(:user, telegram_chat_id: "@meu_usuario")
      expect(user).not_to be_valid
      expect(user.errors[:telegram_chat_id]).to be_present
    end
  end

  describe "#lider? e #executor?" do
    it "identifica um usuário líder" do
      lider = build(:user, :lider)
      expect(lider.lider?).to be true
      expect(lider.executor?).to be false
    end

    it "identifica um usuário executor" do
      executor = build(:user, :executor)
      expect(executor.executor?).to be true
      expect(executor.lider?).to be false
    end
  end
end
