module Users
  # Regra de exclusão de usuário, compartilhada entre a tela web
  # (UsersController) e a API (Api::V1::UsersController) — antes vivia
  # duplicada nos dois controllers, com mensagens de erro ligeiramente
  # diferentes entre eles (risco real de as duas interfaces divergirem
  # silenciosamente depois de uma alteração futura em só um dos lados).
  #
  # Devolve um Result explícito em vez de um boolean: quem chama sabe
  # exatamente por que a exclusão falhou (self_deletion/has_demandas/
  # destroy_failed) sem precisar re-checar as mesmas condições para
  # montar a mensagem certa.
  class Destroy
    Result = Struct.new(:success?, :user, :error_code, :error_message, keyword_init: true)

    def self.call(user:, actor:)
      new(user: user, actor: actor).call
    end

    def initialize(user:, actor:)
      @user = user
      @actor = actor
    end

    def call
      return failure(:self_deletion, "Você não pode excluir o seu próprio usuário.") if user == actor
      return failure(:user_has_demandas, demandas_error_message) if user.demandas.exists?

      if user.destroy
        Result.new(success?: true, user: user)
      else
        # dependent: :restrict_with_error (ver Demanda/User) pode
        # popular user.errors mesmo sem cair no "user.demandas.exists?"
        # acima, em corridas raras — fallback defensivo.
        failure(:destroy_failed, user.errors.full_messages.to_sentence.presence || "Não foi possível excluir o usuário.")
      end
    end

    private

    attr_reader :user, :actor

    def demandas_error_message
      "Não é possível excluir #{user.name}: existem demandas cadastradas por esse usuário."
    end

    def failure(error_code, error_message)
      Result.new(success?: false, user: user, error_code: error_code, error_message: error_message)
    end
  end
end
