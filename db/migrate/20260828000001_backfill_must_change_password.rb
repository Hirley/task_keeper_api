# frozen_string_literal: true

# Corrige o alcance da 20260825000001, que adicionou must_change_password
# com `null: false, default: true` e, com isso, marcou TODO usuário que já
# existia no banco como "ainda precisa definir a própria senha".
#
# Para a maioria deles isso está certo, e não errado: antes daquela
# migration o formulário de /users tinha campo de senha preenchido pelo
# próprio líder (ver app/views/users/_form.html.haml no commit 47c11cc),
# então a senha desses usuários é exatamente o caso que o primeiro acesso
# existe para fechar — provisória, conhecida por quem cadastrou.
#
# O grupo de fato marcado errado é outro, e é estreito: quem já tinha
# usado "esqueci minha senha" e definido a própria senha ANTES da coluna
# existir. Para essas pessoas ninguém mais conhece a senha, e exigir uma
# troca nova é só atrito.
#
# O sinal vem do Devise (:recoverable): num reset concluído com sucesso
# ele limpa o reset_password_token e mantém o reset_password_sent_at. A
# combinação "enviado, mas sem token pendente" identifica quem chegou até
# o fim do fluxo. Quem só pediu o e-mail e abandonou continua com o token
# preenchido e fica de fora, corretamente.
#
# Não é preciso recortar por data: um reset concluído depois que a coluna
# passou a existir já zera a flag sozinho, via User#reset_password. Se o
# registro ainda está com must_change_password = true, o reset dele é
# necessariamente anterior à coluna — que é justamente o que se quer pegar.
class BackfillMustChangePassword < ActiveRecord::Migration[8.1]
  def up
    execute(<<~SQL.squish)
      UPDATE users
         SET must_change_password = false
       WHERE must_change_password = true
         AND reset_password_sent_at IS NOT NULL
         AND reset_password_token IS NULL
    SQL
  end

  # No-op de propósito, em vez de IrreversibleMigration. Desfazer seria
  # remarcar como "senha provisória" gente que definiu a própria senha —
  # ou seja, recriar o defeito. E travar o `db:rollback` de quem só quer
  # voltar um passo no schema seria pior que não ter o que desfazer.
  def down; end
end
