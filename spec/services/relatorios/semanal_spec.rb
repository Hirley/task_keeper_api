require "rails_helper"

RSpec.describe Relatorios::Semanal do
  let(:lider) { create(:user, :lider) }

  describe "#gerar" do
    it "considera um período dos últimos 7 dias corridos, incluindo hoje" do
      resultado = described_class.new.gerar

      expect(resultado.periodo_fim).to eq(Date.current)
      expect(resultado.periodo_inicio).to eq(Date.current - 6)
    end

    it "lista demandas criadas dentro do período" do
      dentro = create(:demanda, title: "Dentro do período", user: lider, created_at: 2.days.ago)
      create(:demanda, title: "Fora do período", user: lider, created_at: 10.days.ago)

      resultado = described_class.new.gerar

      expect(resultado.criadas).to include(dentro)
      expect(resultado.criadas.map(&:title)).not_to include("Fora do período")
    end

    it "lista demandas concluídas cujo updated_at caiu dentro do período" do
      concluida_recente = create(:demanda, :concluida, title: "Concluída recente", user: lider)
      concluida_recente.update_column(:updated_at, 1.day.ago)

      concluida_antiga = create(:demanda, :concluida, title: "Concluída antiga", user: lider)
      concluida_antiga.update_column(:updated_at, 30.days.ago)

      pendente = create(:demanda, title: "Ainda pendente", user: lider)
      pendente.update_column(:updated_at, 1.day.ago)

      resultado = described_class.new.gerar

      expect(resultado.concluidas).to include(concluida_recente)
      expect(resultado.concluidas).not_to include(concluida_antiga)
      expect(resultado.concluidas).not_to include(pendente)
    end

    it "conta demandas por status (situação atual, não só do período)" do
      create(:demanda, status: :pendente, user: lider)
      create(:demanda, :em_andamento, user: lider)
      create(:demanda, :concluida, user: lider)

      resultado = described_class.new.gerar

      expect(resultado.status_counts).to eq("pendente" => 1, "em_andamento" => 1, "concluida" => 1)
    end

    it "conta demandas atrasadas (não concluídas, com data no passado)" do
      create(:demanda, data: 2.days.ago.to_date, status: :pendente, user: lider)
      create(:demanda, data: 2.days.ago.to_date, status: :concluida, user: lider)
      create(:demanda, data: Date.current, status: :pendente, user: lider)

      resultado = described_class.new.gerar

      expect(resultado.atrasadas).to eq(1)
    end

    it "monta a carga por responsável só com demandas em aberto, da maior pra menor" do
      ana = create(:user, name: "Ana")
      bruno = create(:user, name: "Bruno")
      create_list(:demanda, 2, user: ana, status: :pendente)
      create(:demanda, user: bruno, status: :pendente)
      create(:demanda, user: ana, status: :concluida)

      resultado = described_class.new.gerar

      expect(resultado.carga_por_responsavel).to eq([["Ana", 2], ["Bruno", 1]])
    end
  end
end
