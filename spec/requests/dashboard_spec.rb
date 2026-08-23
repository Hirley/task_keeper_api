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

    it "traz o item 'Início' no menu, ativo, e não repete o título como heading visível" do
      sign_in executor

      get '/'

      expect(response.body).to include('<title>Início · Task Keeper API</title>')
      expect(response.body).to include('visually-hidden')
      expect(response.body).to include('>Início<')
    end
  end
end
