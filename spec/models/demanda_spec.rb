require "rails_helper"

RSpec.describe Demanda, type: :model do
  subject(:demanda) { build(:demanda) }

  it { is_expected.to belong_to(:user) }
  it { is_expected.to validate_presence_of(:title) }
  it { is_expected.to validate_presence_of(:data) }
  it { is_expected.to define_enum_for(:status).with_values(pendente: 0, em_andamento: 1, concluida: 2) }

  it "é válida com atributos válidos" do
    expect(demanda).to be_valid
  end

  it "vem por padrão com a data de hoje quando nenhuma data é informada" do
    expect(Demanda.new.data).to eq(Date.current)
  end

  it "permite informar outra data na criação" do
    outra_data = 3.days.from_now.to_date
    demanda = create(:demanda, data: outra_data)

    expect(demanda.reload.data).to eq(outra_data)
  end

  it "pode ser criada tanto por um líder quanto por um executor" do
    lider_demanda = build(:demanda, user: build(:user, :lider))
    executor_demanda = build(:demanda, user: build(:user, :executor))

    expect(lider_demanda).to be_valid
    expect(executor_demanda).to be_valid
  end

  describe "#atraso_notificado_em" do
    it "é zerado quando a data é adiada para hoje ou o futuro" do
      demanda = create(:demanda, data: 3.days.ago.to_date, atraso_notificado_em: 1.hour.ago)

      demanda.update!(data: Date.current)

      expect(demanda.atraso_notificado_em).to be_nil
    end

    it "é zerado quando a demanda é marcada como concluída" do
      demanda = create(:demanda, data: 3.days.ago.to_date, atraso_notificado_em: 1.hour.ago)

      demanda.update!(status: :concluida)

      expect(demanda.atraso_notificado_em).to be_nil
    end

    it "não é alterado quando outros campos mudam e ela continua atrasada e não concluída" do
      marcado_em = 1.hour.ago
      demanda = create(:demanda, data: 3.days.ago.to_date, atraso_notificado_em: marcado_em)

      demanda.update!(description: "Nova descrição")

      expect(demanda.reload.atraso_notificado_em).to be_within(1.second).of(marcado_em)
    end
  end
end
