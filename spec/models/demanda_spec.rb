require "rails_helper"

RSpec.describe Demanda, type: :model do
  subject(:demanda) { build(:demanda) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to define_enum_for(:status).with_values(pendente: 0, em_andamento: 1, concluida: 2) }

  it "é válida com atributos válidos" do
    expect(demanda).to be_valid
  end

  it "pode ser criada tanto por um líder quanto por um executor" do
    lider_demanda = build(:demanda, user: build(:user, :lider))
    executor_demanda = build(:demanda, user: build(:user, :executor))

    expect(lider_demanda).to be_valid
    expect(executor_demanda).to be_valid
  end
end
