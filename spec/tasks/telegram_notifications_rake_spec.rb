# frozen_string_literal: true

require 'rails_helper'
require 'rake'

RSpec.describe 'demandas:notificar_atrasos rake task' do
  before(:all) do
    Rails.application.load_tasks if Rake::Task.tasks.none? { |t| t.name == 'demandas:notificar_atrasos' }
  end

  let(:task) { Rake::Task['demandas:notificar_atrasos'] }

  before { task.reenable }

  around do |example|
    token_original = ENV.fetch('TELEGRAM_BOT_TOKEN', nil)
    ENV['TELEGRAM_BOT_TOKEN'] = 'token-de-teste'
    example.run
    ENV['TELEGRAM_BOT_TOKEN'] = token_original
  end

  it 'notifica e marca atraso_notificado_em em uma demanda atrasada com responsável habilitado' do
    responsavel = create(:user, :executor, telegram_chat_id: '123456')
    demanda = create(:demanda, user: responsavel, data: 3.days.ago.to_date, status: :pendente)

    allow(TelegramNotifier).to receive(:notify_atraso).and_return(true)

    task.invoke

    expect(TelegramNotifier).to have_received(:notify_atraso).with(demanda)
    expect(demanda.reload.atraso_notificado_em).to be_present
  end

  it 'não marca atraso_notificado_em quando o envio falha' do
    responsavel = create(:user, :executor, telegram_chat_id: '123456')
    demanda = create(:demanda, user: responsavel, data: 3.days.ago.to_date, status: :pendente)

    allow(TelegramNotifier).to receive(:notify_atraso).and_return(false)

    task.invoke

    expect(demanda.reload.atraso_notificado_em).to be_nil
  end

  # A marca passou a ser escrita ANTES do envio (ver o comentário na
  # task): é isso que impede duas execuções simultâneas de notificarem a
  # mesma demanda. Sem a devolução aqui verificada, uma falha de rede
  # gastaria a notificação para sempre.
  it 'devolve a demanda para a próxima execução quando o envio falha' do
    responsavel = create(:user, :executor, telegram_chat_id: '123456')
    demanda = create(:demanda, user: responsavel, data: 3.days.ago.to_date, status: :pendente)

    allow(TelegramNotifier).to receive(:notify_atraso).and_return(false)
    task.invoke

    allow(TelegramNotifier).to receive(:notify_atraso).and_return(true)
    task.reenable
    task.invoke

    expect(demanda.reload.atraso_notificado_em).to be_present
  end

  it 'reivindica a demanda antes de enviar, e não depois' do
    responsavel = create(:user, :executor, telegram_chat_id: '123456')
    create(:demanda, user: responsavel, data: 3.days.ago.to_date, status: :pendente)

    marca_no_momento_do_envio = nil
    allow(TelegramNotifier).to receive(:notify_atraso) do |demanda|
      marca_no_momento_do_envio = Demanda.where(id: demanda.id).pick(:atraso_notificado_em)
      true
    end

    task.invoke

    expect(marca_no_momento_do_envio).to be_present
  end

  # A corrida de verdade: outra execução da task selecionou a mesma
  # demanda antes de qualquer gravação e só agora tenta reivindicá-la. O
  # UPDATE condicional é quem decide — ela precisa perder.
  it 'faz uma execução concorrente perder a corrida em vez de notificar de novo' do
    responsavel = create(:user, :executor, telegram_chat_id: '123456')
    create(:demanda, user: responsavel, data: 3.days.ago.to_date, status: :pendente)

    linhas_da_concorrente = nil
    allow(TelegramNotifier).to receive(:notify_atraso) do |demanda|
      linhas_da_concorrente = Demanda.where(id: demanda.id, atraso_notificado_em: nil)
                                     .update_all(atraso_notificado_em: Time.current)
      true
    end

    task.invoke

    expect(linhas_da_concorrente).to eq(0)
  end

  it 'não notifica de novo uma demanda que já foi notificada' do
    responsavel = create(:user, :executor, telegram_chat_id: '123456')
    create(:demanda, user: responsavel, data: 3.days.ago.to_date, status: :pendente,
                     atraso_notificado_em: 1.hour.ago)

    allow(TelegramNotifier).to receive(:notify_atraso)

    task.invoke

    expect(TelegramNotifier).not_to have_received(:notify_atraso)
  end

  it 'pula uma demanda cujo responsável não tem telegram_chat_id cadastrado' do
    responsavel = create(:user, :executor, telegram_chat_id: nil)
    create(:demanda, user: responsavel, data: 3.days.ago.to_date, status: :pendente)

    allow(TelegramNotifier).to receive(:notify_atraso)

    task.invoke

    expect(TelegramNotifier).not_to have_received(:notify_atraso)
  end

  it 'não notifica uma demanda concluída, mesmo com data no passado' do
    responsavel = create(:user, :executor, telegram_chat_id: '123456')
    create(:demanda, :concluida, user: responsavel, data: 3.days.ago.to_date)

    allow(TelegramNotifier).to receive(:notify_atraso)

    task.invoke

    expect(TelegramNotifier).not_to have_received(:notify_atraso)
  end

  it 'não notifica uma demanda que ainda não está atrasada' do
    responsavel = create(:user, :executor, telegram_chat_id: '123456')
    create(:demanda, user: responsavel, data: Date.current, status: :pendente)

    allow(TelegramNotifier).to receive(:notify_atraso)

    task.invoke

    expect(TelegramNotifier).not_to have_received(:notify_atraso)
  end

  it 'não faz nada quando TELEGRAM_BOT_TOKEN não está configurado' do
    ENV['TELEGRAM_BOT_TOKEN'] = nil
    responsavel = create(:user, :executor, telegram_chat_id: '123456')
    create(:demanda, user: responsavel, data: 3.days.ago.to_date, status: :pendente)

    allow(TelegramNotifier).to receive(:notify_atraso)

    task.invoke

    expect(TelegramNotifier).not_to have_received(:notify_atraso)
  end
end
