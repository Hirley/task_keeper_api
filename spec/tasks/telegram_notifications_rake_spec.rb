require "rails_helper"
require "rake"

RSpec.describe "demandas:notificar_atrasos rake task" do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == "demandas:notificar_atrasos" }
  end

  let(:task) { Rake::Task["demandas:notificar_atrasos"] }

  before { task.reenable }

  around do |example|
    token_original = ENV["TELEGRAM_BOT_TOKEN"]
    ENV["TELEGRAM_BOT_TOKEN"] = "token-de-teste"
    example.run
    ENV["TELEGRAM_BOT_TOKEN"] = token_original
  end

  it "notifica e marca atraso_notificado_em em uma demanda atrasada com responsável habilitado" do
    responsavel = create(:user, :executor, telegram_chat_id: "123456")
    demanda = create(:demanda, user: responsavel, data: 3.days.ago.to_date, status: :pendente)

    allow(TelegramNotifier).to receive(:notify_atraso).and_return(true)

    task.invoke

    expect(TelegramNotifier).to have_received(:notify_atraso).with(demanda)
    expect(demanda.reload.atraso_notificado_em).to be_present
  end

  it "não marca atraso_notificado_em quando o envio falha" do
    responsavel = create(:user, :executor, telegram_chat_id: "123456")
    demanda = create(:demanda, user: responsavel, data: 3.days.ago.to_date, status: :pendente)

    allow(TelegramNotifier).to receive(:notify_atraso).and_return(false)

    task.invoke

    expect(demanda.reload.atraso_notificado_em).to be_nil
  end

  it "não notifica de novo uma demanda que já foi notificada" do
    responsavel = create(:user, :executor, telegram_chat_id: "123456")
    demanda = create(:demanda, user: responsavel, data: 3.days.ago.to_date, status: :pendente,
      atraso_notificado_em: 1.hour.ago)

    allow(TelegramNotifier).to receive(:notify_atraso)

    task.invoke

    expect(TelegramNotifier).not_to have_received(:notify_atraso)
  end

  it "pula uma demanda cujo responsável não tem telegram_chat_id cadastrado" do
    responsavel = create(:user, :executor, telegram_chat_id: nil)
    create(:demanda, user: responsavel, data: 3.days.ago.to_date, status: :pendente)

    allow(TelegramNotifier).to receive(:notify_atraso)

    task.invoke

    expect(TelegramNotifier).not_to have_received(:notify_atraso)
  end

  it "não notifica uma demanda concluída, mesmo com data no passado" do
    responsavel = create(:user, :executor, telegram_chat_id: "123456")
    create(:demanda, :concluida, user: responsavel, data: 3.days.ago.to_date)

    allow(TelegramNotifier).to receive(:notify_atraso)

    task.invoke

    expect(TelegramNotifier).not_to have_received(:notify_atraso)
  end

  it "não notifica uma demanda que ainda não está atrasada" do
    responsavel = create(:user, :executor, telegram_chat_id: "123456")
    create(:demanda, user: responsavel, data: Date.current, status: :pendente)

    allow(TelegramNotifier).to receive(:notify_atraso)

    task.invoke

    expect(TelegramNotifier).not_to have_received(:notify_atraso)
  end

  it "não faz nada quando TELEGRAM_BOT_TOKEN não está configurado" do
    ENV["TELEGRAM_BOT_TOKEN"] = nil
    responsavel = create(:user, :executor, telegram_chat_id: "123456")
    create(:demanda, user: responsavel, data: 3.days.ago.to_date, status: :pendente)

    allow(TelegramNotifier).to receive(:notify_atraso)

    task.invoke

    expect(TelegramNotifier).not_to have_received(:notify_atraso)
  end
end
