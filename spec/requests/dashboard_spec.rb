# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Painel inicial (dashboard)', type: :request do
  let(:lider) { create(:user, :lider) }
  let(:executor) { create(:user, :executor) }

  def minhas_demandas_table(response)
    response.body[%r{<table.*?</table>}m]
  end

  describe 'GET /' do
    it 'exige autenticação' do
      get '/'
      expect(response).to redirect_to(new_user_session_path)
    end

    it 'mostra os totais por status' do
      create(:demanda, status: :pendente, user: lider)
      create(:demanda, status: :pendente, user: lider)
      create(:demanda, status: :em_andamento, user: lider)
      create(:demanda, status: :concluida, user: lider)
      sign_in lider

      get '/'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<div class="stat-value">4</div>')
      expect(response.body).to include('<div class="stat-value">2</div>')
      expect(response.body).to include('<div class="stat-value">1</div>')
    end

    it 'os KPIs de status são links de drilldown pra Demandas já filtrada' do
      create(:demanda, status: :pendente, user: lider)
      sign_in lider

      get '/'

      expect(response.body).to include('href="/demandas"')
      expect(response.body).to include('href="/demandas?status%5B%5D=pendente"')
      expect(response.body).to include('href="/demandas?status%5B%5D=em_andamento"')
      expect(response.body).to include('href="/demandas?status%5B%5D=concluida"')
    end

    it 'os prazos (Atrasadas/Vencem hoje/Vencem em breve) são links de drilldown' do
      sign_in lider

      get '/'

      expect(response.body).to include('href="/demandas?prazo=atrasada"')
      expect(response.body).to include('href="/demandas?prazo=hoje"')
      expect(response.body).to include('href="/demandas?prazo=breve"')
    end

    it 'a carga por responsável é um link de drilldown pra Demandas filtrada por responsável' do
      demanda = create(:demanda, status: :pendente, user: lider)
      sign_in lider

      get '/'

      expect(response.body).to include("href=\"/demandas?responsavel_id=#{demanda.user_id}\"")
    end

    it 'o card Equipe tem um link de drilldown por papel, pra Acessos' do
      admin = create(:user, :admin)
      sign_in admin

      get '/'

      expect(response.body).to include('href="/users?role%5B%5D=admin"')
      expect(response.body).to include('href="/users?role%5B%5D=lider"')
      expect(response.body).to include('href="/users?role%5B%5D=executor"')
    end

    it 'mostra estado vazio quando não há nenhuma demanda' do
      sign_in lider

      get '/'

      expect(response).to have_http_status(:ok)
      expect(response.body).to include('<div class="stat-value">0</div>')
      expect(response.body).to include('Nenhuma demanda cadastrada ainda.')
    end

    it "em 'Minhas demandas' mostra só as demandas do usuário logado" do
      create(:demanda, title: 'Demanda do líder', user: lider)
      create(:demanda, title: 'Demanda do executor', user: executor)
      sign_in lider

      get '/'

      table = minhas_demandas_table(response)
      expect(table).to include('Demanda do líder')
      expect(table).not_to include('Demanda do executor')
    end

    it 'não tem mais o link de texto "Ver todas" — o cabeçalho do card inteiro já é o link' do
      sign_in lider

      get '/'

      expect(response.body).not_to include('Ver todas')
      expect(response.body).to include(%(class="card-drilldown" href="/demandas?responsavel_id=#{lider.id}"))
    end

    it '"Atividade recente" tem o cabeçalho como link pra listagem completa' do
      sign_in lider

      get '/'

      expect(response.body).to include('class="card-drilldown" href="/demandas"')
    end

    it 'um item de "Atividade recente" abre a edição direto quando quem vê pode editar (líder/admin)' do
      demanda = create(:demanda, title: 'Revisar contrato', user: executor)
      sign_in lider

      get '/'

      expect(response.body).to include(%(class="activity-item-link" href="/demandas/#{demanda.id}/edit"))
    end

    it 'um item de "Atividade recente" abre a listagem filtrada por título quando quem vê não pode editar (executor)' do
      create(:demanda, title: 'Revisar contrato', user: lider)
      sign_in executor

      get '/'

      expect(response.body).to include('class="activity-item-link" href="/demandas?q=Revisar+contrato"')
    end

    it 'sinaliza uma demanda atrasada com o badge de urgência' do
      create(:demanda, title: 'Demanda atrasada', status: :pendente, data: 3.days.ago.to_date, user: lider)
      sign_in lider

      get '/'

      expect(response.body).to include('Atrasada há 3 dias')
    end

    it 'sinaliza uma demanda que vence hoje' do
      create(:demanda, title: 'Demanda de hoje', status: :em_andamento, data: Date.current, user: lider)
      sign_in lider

      get '/'

      expect(response.body).to include('Vence hoje')
    end

    it 'não mostra badge de urgência para demanda concluída, mesmo com data no passado' do
      create(:demanda, title: 'Demanda antiga concluída', status: :concluida, data: 5.days.ago.to_date, user: lider)
      sign_in lider

      get '/'

      table = minhas_demandas_table(response)
      expect(table).to include('Demanda antiga concluída')
      expect(table).not_to include('Atrasada')
    end

    it 'conta atrasadas, vencendo hoje e vencendo em breve para toda a equipe' do
      create(:demanda, status: :pendente, data: 1.day.ago.to_date, user: lider)
      create(:demanda, status: :pendente, data: 2.days.ago.to_date, user: executor)
      create(:demanda, status: :em_andamento, data: Date.current, user: lider)
      create(:demanda, status: :pendente, data: 2.days.from_now.to_date, user: executor)
      # concluída não deve contar em nenhum balde, mesmo com data vencida
      create(:demanda, status: :concluida, data: 1.day.ago.to_date, user: lider)
      sign_in lider

      get '/'

      expect(response.body).to include('<span class="prazo-count prazo-count-critical">2</span>')
      expect(response.body).to include('<span class="prazo-count prazo-count-warning">1</span>')
      expect(response.body).to include('<span class="prazo-count prazo-count-neutral">1</span>')
    end

    it 'mostra a carga por responsável só com demandas abertas, da maior para a menor' do
      # nomes próprios, diferentes do usuário logado, para não aparecerem
      # em outro lugar da página (navbar/saudação) além da lista de carga
      responsavel_a = create(:user, :executor, name: 'Ana Carga')
      responsavel_b = create(:user, :executor, name: 'Bruno Carga')
      create_list(:demanda, 3, status: :pendente, user: responsavel_a)
      create(:demanda, status: :em_andamento, user: responsavel_b)
      create(:demanda, status: :concluida, user: responsavel_b) # não deve contar como carga aberta
      sign_in lider

      get '/'

      # "Ana Carga"/"Bruno Carga" também podem aparecer em "Atividade
      # recente" (que lista as demandas mais novas primeiro, então nem
      # sempre na mesma ordem da carga por responsável) — como essa
      # seção vem ANTES de "Carga por responsável" no HTML, basta
      # restringir a checagem de ordem a partir do id da segunda seção
      # em diante (nenhuma outra seção depois dela repete esses nomes).
      carga_section = response.body[/id="carga-por-responsavel".*/m]
      pos_a = carga_section.index('Ana Carga')
      pos_b = carga_section.index('Bruno Carga')
      expect(pos_a).to be < pos_b
      expect(carga_section).to include('<span class="load-count">3</span>')
      expect(carga_section).to include('<span class="load-count">1</span>')
    end

    it 'mostra o card Equipe para o líder' do
      sign_in lider

      get '/'

      expect(response.body).to include('Equipe')
      expect(response.body).to include('líder(es)')
    end

    it 'mostra o card Equipe para o admin também' do
      admin = create(:user, :admin)
      sign_in admin

      get '/'

      expect(response.body).to include('Equipe')
      expect(response.body).to include('admin(s)')
    end

    it 'não mostra o card Equipe para o executor' do
      sign_in executor

      get '/'

      expect(response.body).not_to include('líder(es)')
    end

    it 'não repete o título como heading visível; a marca leva pra home, sem item "Início" no menu' do
      sign_in executor

      get '/'

      expect(response.body).to include('<title>Início · Task Keeper API</title>')
      expect(response.body).to include('visually-hidden')
      expect(response.body).not_to include('>Início</a>')
      expect(response.body).to include('<a class="navbar-brand tk-brand" href="/">')
    end
  end
end
