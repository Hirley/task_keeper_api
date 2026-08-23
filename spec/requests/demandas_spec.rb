# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Demandas (tela web)', type: :request do
  let(:lider) { create(:user, :lider) }
  let(:executor) { create(:user, :executor) }

  # A tela de listagem tem um <datalist> de autocomplete com TODOS os
  # títulos cadastrados (sem respeitar filtro/ordenação — é só uma
  # sugestão de busca). Para não confundir esse datalist com os
  # resultados exibidos na tabela, os testes de filtro/ordenação devem
  # inspecionar apenas o HTML dentro do <tbody> da tabela de resultados.
  def results_table(response)
    response.body[%r{<tbody>.*?</tbody>}m]
  end

  describe 'GET /demandas' do
    it 'mostra o botão de nova demanda mas esconde as ações de editar/excluir para o executor' do
      create(:demanda, user: lider)
      sign_in executor

      get '/demandas'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Nova demanda')
      expect(response.body).not_to include('Editar')
      expect(response.body).not_to include('Excluir')
    end

    it 'mostra as ações de editar e excluir para o líder' do
      create(:demanda, user: executor)
      sign_in lider

      get '/demandas'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('Nova demanda')
      expect(response.body).to include('Editar')
      expect(response.body).to include('Excluir')
    end

    it 'carrega o importmap com o Turbo para o alerta de confirmação funcionar' do
      sign_in executor

      get '/demandas'

      expect(response.body).to include('type="importmap"')
      expect(response.body).to include('@hotwired/turbo-rails')
    end

    it 'não repete o título da página como um heading visível igual ao item do menu' do
      sign_in executor

      get '/demandas'

      expect(response.body).to include('<title>Demandas · Task Keeper API</title>')
      expect(response.body).to include('visually-hidden')
    end

    it 'os alertas de flash podem ser fechados (têm botão de fechar)' do
      sign_in executor
      post '/demandas', params: { demanda: { title: 'Nova demanda web' } }

      follow_redirect!

      expect(response.body).to include('alert-dismissible')
      expect(response.body).to include('btn-close')
    end

    it 'pede confirmação antes de excluir' do
      create(:demanda, user: executor)
      sign_in lider

      get '/demandas'

      expect(response.body).to include('data-turbo-confirm')
      expect(response.body).to include('Tem certeza que deseja excluir esta demanda?')
    end

    it 'filtra por título via o formulário de busca' do
      create(:demanda, title: 'Revisar contrato', user: lider)
      create(:demanda, title: 'Organizar sala', user: lider)
      sign_in lider

      get '/demandas', params: { q: 'contrato' }

      expect(results_table(response)).to include('Revisar contrato')
      expect(results_table(response)).not_to include('Organizar sala')
    end

    it 'filtra por status' do
      create(:demanda, title: 'Demanda pendente', status: :pendente, user: lider)
      create(:demanda, title: 'Demanda concluída', status: :concluida, user: lider)
      sign_in lider

      get '/demandas', params: { status: 'concluida' }

      expect(results_table(response)).to include('Demanda concluída')
      expect(results_table(response)).not_to include('Demanda pendente')
    end

    it 'filtra por mais de um status ao mesmo tempo (select multiple)' do
      create(:demanda, title: 'Demanda pendente', status: :pendente, user: lider)
      create(:demanda, title: 'Demanda em andamento', status: :em_andamento, user: lider)
      create(:demanda, title: 'Demanda concluída', status: :concluida, user: lider)
      sign_in lider

      get '/demandas', params: { status: %w[pendente concluida] }

      table = results_table(response)
      expect(table).to include('Demanda pendente')
      expect(table).to include('Demanda concluída')
      expect(table).not_to include('Demanda em andamento')
    end

    it 'filtra por mais de um termo de título, separados por vírgula' do
      create(:demanda, title: 'Revisar contrato', user: lider)
      create(:demanda, title: 'Organizar sala', user: lider)
      create(:demanda, title: 'Comprar material', user: lider)
      sign_in lider

      get '/demandas', params: { q: 'contrato, sala' }

      table = results_table(response)
      expect(table).to include('Revisar contrato')
      expect(table).to include('Organizar sala')
      expect(table).not_to include('Comprar material')
    end

    it 'filtra por prazo "atrasada" (drilldown do painel inicial)' do
      create(:demanda, title: 'Demanda atrasada', status: :pendente, data: 3.days.ago.to_date, user: lider)
      create(:demanda, title: 'Demanda em dia', status: :pendente, data: 3.days.from_now.to_date, user: lider)
      create(:demanda, title: 'Concluída mas com data passada', status: :concluida, data: 3.days.ago.to_date, user: lider)
      sign_in lider

      get '/demandas', params: { prazo: 'atrasada' }

      table = results_table(response)
      expect(table).to include('Demanda atrasada')
      expect(table).not_to include('Demanda em dia')
      expect(table).not_to include('Concluída mas com data passada')
    end

    it 'filtra por prazo "hoje"' do
      create(:demanda, title: 'Vence hoje', status: :pendente, data: Date.current, user: lider)
      create(:demanda, title: 'Vence amanhã', status: :pendente, data: 1.day.from_now.to_date, user: lider)
      sign_in lider

      get '/demandas', params: { prazo: 'hoje' }

      table = results_table(response)
      expect(table).to include('Vence hoje')
      expect(table).not_to include('Vence amanhã')
    end

    it 'filtra por prazo "breve" (dentro da janela de PRAZO_PROXIMO_DIAS, sem contar hoje)' do
      create(:demanda, title: 'Vence em 2 dias', status: :pendente, data: 2.days.from_now.to_date, user: lider)
      create(:demanda, title: 'Vence hoje', status: :pendente, data: Date.current, user: lider)
      create(:demanda, title: 'Vence muito longe', status: :pendente, data: 30.days.from_now.to_date, user: lider)
      sign_in lider

      get '/demandas', params: { prazo: 'breve' }

      table = results_table(response)
      expect(table).to include('Vence em 2 dias')
      expect(table).not_to include('Vence hoje')
      expect(table).not_to include('Vence muito longe')
    end

    it 'ignora um valor de prazo desconhecido/malicioso' do
      create(:demanda, title: 'Demanda qualquer', user: lider)
      sign_in lider

      get '/demandas', params: { prazo: "1' OR '1'='1" }

      expect(response).to have_http_status(:ok)
      expect(results_table(response)).to include('Demanda qualquer')
    end

    it 'filtra por responsável (drilldown de "carga por responsável" no painel inicial)' do
      outro_lider = create(:user, :lider, name: 'Outro Líder')
      create(:demanda, title: 'Demanda do líder', user: lider)
      create(:demanda, title: 'Demanda do outro líder', user: outro_lider)
      sign_in lider

      get '/demandas', params: { responsavel_id: lider.id }

      table = results_table(response)
      expect(table).to include('Demanda do líder')
      expect(table).not_to include('Demanda do outro líder')
    end

    it 'mostra um aviso de drilldown (com link pra limpar) quando vem filtrado por prazo ou responsável' do
      create(:demanda, user: lider)
      sign_in lider

      get '/demandas', params: { prazo: 'atrasada' }

      expect(response.body).to include('Vindo do painel')
      expect(response.body).to include('Limpar filtro')
    end

    it 'não mostra o aviso de drilldown numa visita normal (sem prazo/responsável)' do
      sign_in lider

      get '/demandas'

      expect(response.body).not_to include('Vindo do painel')
    end

    it 'pagina os resultados quando há mais de 10 demandas' do
      create_list(:demanda, 11, user: lider)
      sign_in lider

      get '/demandas'

      expect(response.body).to include('Próxima')

      get '/demandas', params: { page: 2 }
      expect(response).to have_http_status(:ok)
    end

    it 'ordena por título quando a coluna é clicada' do
      create(:demanda, title: 'Zebra', user: lider)
      create(:demanda, title: 'Abacaxi', user: lider)
      sign_in lider

      get '/demandas', params: { sort: 'title', direction: 'asc' }

      table = results_table(response)
      expect(table.index('Abacaxi')).to be < table.index('Zebra')
    end

    it 'inverte a direção da ordenação ao clicar novamente na mesma coluna' do
      create(:demanda, title: 'Zebra', user: lider)
      create(:demanda, title: 'Abacaxi', user: lider)
      sign_in lider

      get '/demandas', params: { sort: 'title', direction: 'desc' }

      table = results_table(response)
      expect(table.index('Zebra')).to be < table.index('Abacaxi')
    end

    it 'ordena por responsável' do
      ana = create(:user, name: 'Ana')
      bruno = create(:user, name: 'Bruno')
      create(:demanda, title: 'Demanda do Bruno', user: bruno)
      create(:demanda, title: 'Demanda da Ana', user: ana)
      sign_in lider

      get '/demandas', params: { sort: 'responsavel', direction: 'asc' }

      table = results_table(response)
      expect(table.index('Demanda da Ana')).to be < table.index('Demanda do Bruno')
    end

    it 'ordena por status' do
      create(:demanda, title: 'Demanda concluída', status: :concluida, user: lider)
      create(:demanda, title: 'Demanda pendente', status: :pendente, user: lider)
      sign_in lider

      get '/demandas', params: { sort: 'status', direction: 'asc' }

      table = results_table(response)
      expect(table.index('Demanda pendente')).to be < table.index('Demanda concluída')
    end

    it 'ordena por data' do
      create(:demanda, title: 'Demanda futura', data: 10.days.from_now.to_date, user: lider)
      create(:demanda, title: 'Demanda de hoje', data: Date.current, user: lider)
      sign_in lider

      get '/demandas', params: { sort: 'data', direction: 'asc' }

      table = results_table(response)
      expect(table.index('Demanda de hoje')).to be < table.index('Demanda futura')
    end

    it 'por padrão ordena por criada em, mais recente primeiro' do
      create(:demanda, title: 'Demanda antiga', user: lider, created_at: 2.days.ago)
      create(:demanda, title: 'Demanda recente', user: lider, created_at: 1.hour.ago)
      sign_in lider

      get '/demandas'

      table = results_table(response)
      expect(table.index('Demanda recente')).to be < table.index('Demanda antiga')
    end

    it 'ignora um parâmetro de ordenação inválido/malicioso e não quebra a página' do
      create(:demanda, user: lider)
      sign_in lider

      get '/demandas', params: { sort: '1; DROP TABLE demandas;--', direction: 'asc' }

      expect(response).to have_http_status(:ok)
    end
  end

  describe 'GET /demandas/new' do
    it 'permite que um executor acesse o formulário de criação' do
      sign_in executor
      get '/demandas/new'
      expect(response).to have_http_status(:ok)
    end

    it 'permite que um líder acesse o formulário de criação' do
      sign_in lider
      get '/demandas/new'
      expect(response).to have_http_status(:ok)
    end

    it 'traz o campo de data preenchido com a data atual por padrão' do
      sign_in executor
      get '/demandas/new'

      expect(response.body).to include(%(value="#{Date.current.iso8601}"))
    end
  end

  describe 'POST /demandas' do
    it 'permite que um executor crie uma demanda pela tela' do
      sign_in executor
      expect do
        post '/demandas', params: { demanda: { title: 'Nova demanda web' } }
      end.to change(Demanda, :count).by(1)
      expect(response).to redirect_to(demandas_path)
    end

    it 'permite que um líder crie uma demanda pela tela' do
      sign_in lider
      expect do
        post '/demandas', params: { demanda: { title: 'Nova demanda web' } }
      end.to change(Demanda, :count).by(1)
      expect(response).to redirect_to(demandas_path)
    end

    it 'usa a data de hoje quando o campo de data não é alterado' do
      sign_in executor
      post '/demandas', params: { demanda: { title: 'Nova demanda web' } }
      expect(Demanda.last.data).to eq(Date.current)
    end

    it 'permite que um executor selecione outra data ao cadastrar' do
      outra_data = 7.days.from_now.to_date
      sign_in executor
      post '/demandas', params: { demanda: { title: 'Nova demanda web', data: outra_data } }
      expect(Demanda.last.data).to eq(outra_data)
    end
  end

  describe 'GET /demandas/:id/edit' do
    let!(:demanda) { create(:demanda, user: lider) }

    it 'bloqueia um executor' do
      sign_in executor
      get "/demandas/#{demanda.id}/edit"
      expect(response).to redirect_to(root_path)
    end

    it 'permite um líder' do
      sign_in lider
      get "/demandas/#{demanda.id}/edit"
      expect(response).to have_http_status(:ok)
    end
  end

  describe 'PATCH /demandas/:id' do
    let!(:demanda) { create(:demanda, user: lider) }

    it 'bloqueia um executor e não altera a demanda' do
      sign_in executor
      patch "/demandas/#{demanda.id}", params: { demanda: { title: 'Alterada' } }
      expect(response).to redirect_to(root_path)
      expect(demanda.reload.title).not_to eq('Alterada')
    end

    it 'permite que um líder atualize a demanda' do
      sign_in lider
      patch "/demandas/#{demanda.id}", params: { demanda: { title: 'Alterada' } }
      expect(response).to redirect_to(demandas_path)
      expect(demanda.reload.title).to eq('Alterada')
    end

    it 'impede que um executor altere a data de uma demanda já cadastrada' do
      outra_data = 15.days.from_now.to_date
      sign_in executor
      patch "/demandas/#{demanda.id}", params: { demanda: { data: outra_data } }
      expect(response).to redirect_to(root_path)
      expect(demanda.reload.data).not_to eq(outra_data)
    end

    it 'permite que um líder altere a data de uma demanda já cadastrada' do
      outra_data = 15.days.from_now.to_date
      sign_in lider
      patch "/demandas/#{demanda.id}", params: { demanda: { data: outra_data } }
      expect(response).to redirect_to(demandas_path)
      expect(demanda.reload.data).to eq(outra_data)
    end
  end

  describe 'DELETE /demandas/:id' do
    let!(:demanda) { create(:demanda, user: lider) }

    it 'bloqueia um executor e não exclui a demanda' do
      sign_in executor
      expect do
        delete "/demandas/#{demanda.id}"
      end.not_to change(Demanda, :count)
      expect(response).to redirect_to(root_path)
    end

    it 'permite que um líder exclua a demanda' do
      sign_in lider
      expect do
        delete "/demandas/#{demanda.id}"
      end.to change(Demanda, :count).by(-1)
      expect(response).to redirect_to(demandas_path)
    end
  end
end
