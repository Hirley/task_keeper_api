# frozen_string_literal: true

module Api
  module V1
    class DemandasController < BaseController
      before_action :set_demanda, only: %i[show update destroy]

      # GET /api/v1/demandas
      def index
        @demandas = Demanda.accessible_by(current_ability).order(created_at: :desc)
        render json: @demandas
      end

      # GET /api/v1/demandas/:id
      def show
        authorize! :read, @demanda
        render json: @demanda
      end

      # POST /api/v1/demandas
      # Ambos os papéis (líder e executor) podem criar demandas.
      def create
        authorize! :create, Demanda
        @demanda = current_user.demandas.new(demanda_params)

        if @demanda.save
          render json: @demanda, status: :created
        else
          render json: { errors: @demanda.errors.full_messages }, status: :unprocessable_content
        end
      end

      # PATCH/PUT /api/v1/demandas/:id
      # Apenas o líder pode atualizar uma demanda já existente.
      def update
        authorize! :update, @demanda

        if @demanda.update(demanda_params)
          render json: @demanda
        else
          render json: { errors: @demanda.errors.full_messages }, status: :unprocessable_content
        end
      end

      # DELETE /api/v1/demandas/:id
      # Apenas o líder pode excluir uma demanda já existente.
      #
      # O 422 não é alcançável hoje — nada impede a exclusão de uma
      # demanda. Existe porque antes o 204 era devolvido sem olhar o
      # retorno de #destroy: um `dependent: :restrict_with_error` ou um
      # `before_destroy` que aborte fariam a API responder "excluída" com
      # o registro ainda no banco. Ver o comentário equivalente em
      # DemandasController#destroy (tela web).
      def destroy
        authorize! :destroy, @demanda

        if @demanda.destroy
          head :no_content
        else
          render json: { errors: erros_de_exclusao }, status: :unprocessable_content
        end
      end

      private

      # Mesmo formato de erro de #create/#update (array de strings). Um
      # `before_destroy` com `throw :abort` devolve false sem popular
      # errors, daí o fallback — a resposta nunca sai com a lista vazia.
      def erros_de_exclusao
        @demanda.errors.full_messages.presence || ['Não foi possível excluir a demanda.']
      end

      def set_demanda
        @demanda = Demanda.find(params[:id])
      end

      def demanda_params
        params.require(:demanda).permit(:title, :description, :status, :data)
      end
    end
  end
end
