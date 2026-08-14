require "net/http"
require "json"

# Envia lembretes de demanda atrasada via Telegram Bot API
# (https://core.telegram.org/bots/api#sendmessage).
#
# Configuração necessária:
#   - ENV["TELEGRAM_BOT_TOKEN"]: token do bot, criado com o @BotFather.
#   - User#telegram_chat_id: cada usuário que deve receber avisos precisa
#     ter esse campo preenchido (o líder cadastra/edita em /users). Para
#     descobrir o próprio chat_id, o usuário conversa com um bot como
#     @userinfobot no Telegram.
#
# Sem token configurado, ou sem chat_id no responsável pela demanda,
# #notify_atraso simplesmente não envia nada e retorna false — não é
# tratado como erro, porque nem todo ambiente/usuário precisa ter isso
# configurado (ver lib/tasks/telegram_notifications.rake, que chama isso
# periodicamente).
class TelegramNotifier
  API_BASE = "https://api.telegram.org".freeze

  DEFAULT_TRANSPORT = lambda do |uri, body|
    Net::HTTP.post(uri, body, "Content-Type" => "application/json")
  end

  # Transporte pro envio de documentos (sendDocument é multipart/form-data
  # — upload de arquivo —, não JSON como sendMessage, por isso é um
  # transporte separado do DEFAULT_TRANSPORT). Usado pelo relatório
  # semanal em PDF (ver #enviar_documento e RelatoriosController).
  DEFAULT_DOCUMENT_TRANSPORT = lambda do |uri, chat_id, filename, arquivo, legenda|
    Net::HTTP.start(uri.host, uri.port, use_ssl: true) do |http|
      request = Net::HTTP::Post.new(uri)
      request.set_form(
        [
          ["chat_id", chat_id],
          ["caption", legenda],
          ["document", arquivo, { filename: filename, content_type: "application/pdf" }]
        ],
        "multipart/form-data"
      )
      http.request(request)
    end
  end

  def self.notify_atraso(demanda)
    new.notify_atraso(demanda)
  end

  # +transport+/+document_transport+ existem para permitir injetar dublês
  # nos testes (evita depender de uma gem de mock de HTTP e evita
  # chamadas de rede reais).
  def initialize(
    bot_token: ENV["TELEGRAM_BOT_TOKEN"],
    transport: DEFAULT_TRANSPORT,
    document_transport: DEFAULT_DOCUMENT_TRANSPORT
  )
    @bot_token = bot_token
    @transport = transport
    @document_transport = document_transport
  end

  def notify_atraso(demanda)
    responsavel = demanda.user
    return false if @bot_token.blank? || responsavel&.telegram_chat_id.blank?

    enviar(responsavel.telegram_chat_id, mensagem_atraso(demanda))
  rescue StandardError => e
    Rails.logger.error("[TelegramNotifier] falha ao notificar a demanda ##{demanda.id}: #{e.message}")
    false
  end

  # Envia um arquivo (ex.: o PDF do relatório semanal — ver
  # Relatorios::SemanalPdf) como documento pro chat_id de +usuario+. Mesma
  # filosofia de #notify_atraso: sem token configurado, ou sem chat_id
  # cadastrado, não é erro — só não envia (retorna false), quem chama
  # decide como avisar quem pediu o envio (ver RelatoriosController).
  def enviar_documento(usuario, filename:, conteudo:, legenda: nil)
    return false if @bot_token.blank? || usuario&.telegram_chat_id.blank?

    uri = URI("#{API_BASE}/bot#{@bot_token}/sendDocument")
    response = @document_transport.call(uri, usuario.telegram_chat_id, filename, conteudo, legenda.to_s)
    response.is_a?(Net::HTTPSuccess)
  rescue StandardError => e
    Rails.logger.error("[TelegramNotifier] falha ao enviar documento pro usuário ##{usuario&.id}: #{e.message}")
    false
  end

  private

  # Empática (reconhece que atraso acontece, não cobra) e objetiva (diz
  # exatamente qual demanda, há quanto tempo, e o que fazer a seguir).
  #
  # Usa o nome completo (não só o primeiro nome) porque o app já segue
  # essa convenção na saudação do painel inicial ("Olá, #{nome completo}"
  # em app/views/dashboard/index.html.haml) — e evita cortar errado nomes
  # compostos comuns no Brasil, como "Ana Paula" ou "Maria Clara".
  def mensagem_atraso(demanda)
    dias = [(Date.current - demanda.data).to_i, 1].max
    prazo = demanda.data.strftime("%d/%m/%Y")

    <<~MSG.strip
      Oi, #{demanda.user.name}! 👋

      Passando para lembrar com carinho: a demanda "#{demanda.title}" está #{dias == 1 ? "há 1 dia" : "há #{dias} dias"} com o prazo vencido (era #{prazo}).

      Sem cobrança — só um lembrete objetivo. Se estiver precisando de mais tempo ou de uma mão, vale alinhar com o seu líder. Se já está resolvida, é só atualizar o status em Demandas.
    MSG
  end

  def enviar(chat_id, texto)
    uri = URI("#{API_BASE}/bot#{@bot_token}/sendMessage")
    body = { chat_id: chat_id, text: texto }.to_json
    response = @transport.call(uri, body)
    response.is_a?(Net::HTTPSuccess)
  end
end
