// app/javascript/application.js

import "@hotwired/turbo-rails";
import { Application } from "@hotwired/stimulus";
import { eagerLoadControllersFrom } from "@hotwired/stimulus-loading";

// --- INICIO DE STIMULUS ---
const application = Application.start();

// Configura la experiencia de desarrollo de Stimulus
application.debug = false; // Cambia a true para depurar
window.Stimulus = application;

// Carga automáticamente todos los controladores desde la carpeta "controllers"
// La magia de importmap-rails se encarga del resto.
eagerLoadControllersFrom("controllers", application);
// -----------------------

// Import payment integration
import "payment_integration"