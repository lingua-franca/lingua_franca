# desc "Explaining what the task does"
require 'lingua_franca/translation_importer'

namespace :lingua_franca do
	task :import do
		LinguaFranca::TranslationImporter::import!
	end
end
