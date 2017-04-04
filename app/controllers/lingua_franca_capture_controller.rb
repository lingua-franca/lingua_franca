
class LinguaFrancaCaptureController < ActionController::Base

  def capture
    LinguaFranca.capture_request(params[:a], params[:c])
    render text: 'ok'
  end

end
