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
          render json: { errors: @demanda.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # PATCH/PUT /api/v1/demandas/:id
      # Apenas o líder pode atualizar uma demanda já existente.
      def update
        authorize! :update, @demanda

        if @demanda.update(demanda_params)
          render json: @demanda
        else
          render json: { errors: @demanda.errors.full_messages }, status: :unprocessable_entity
        end
      end

      # DELETE /api/v1/demandas/:id
      # Apenas o líder pode excluir uma demanda já existente.
      def destroy
        authorize! :destroy, @demanda
        @demanda.destroy
        head :no_content
      end

      private

      def set_demanda
        @demanda = Demanda.find(params[:id])
      end

      def demanda_params
        params.require(:demanda).permit(:title, :description, :status, :data)
      end
    end
  end
end
