// Payment Integration JavaScript
// This handles Stripe and PayPal payment processing

document.addEventListener('DOMContentLoaded', function() {
  console.log('Payment Integration loaded');
  
  // Initialize all payment containers
  initializePaymentContainers();
});

function initializePaymentContainers() {
  const paymentContainers = document.querySelectorAll('[data-payment-container="true"]');
  
  paymentContainers.forEach(container => {
    initializePaymentForContainer(container);
  });
}

function initializePaymentForContainer(container) {
  try {
    console.log('Initializing payment for container:', container);
    
    // Initialize payment method selection
    initializePaymentMethodSelection(container);

    // Initialize Stripe if available
    if (typeof Stripe !== 'undefined') {
      console.log('Stripe SDK loaded');
      initializeStripePayment(container);
    } else {
      console.warn('Stripe.js not loaded, showing manual input');
      showManualCardInput(container);
    }

    // Initialize PayPal if available
    if (typeof paypal !== 'undefined') {
      console.log('PayPal SDK loaded');
      initializePayPalPayment(container);
    } else {
      console.warn('PayPal SDK not loaded');
    }

    // Show default payment method
    const defaultMethod = getSelectedPaymentMethod(container) || 'credit_card';
    showPaymentMethod(container, defaultMethod);
    
  } catch (error) {
    console.error('Error initializing payment container:', error);
    showManualCardInput(container);
  }
}

function initializePaymentMethodSelection(container) {
  const paymentMethodRadios = container.querySelectorAll('input[name="answer[payment_method]"]');
  
  paymentMethodRadios.forEach(radio => {
    radio.addEventListener('change', function() {
      console.log('Payment method changed to:', this.value);
      showPaymentMethod(container, this.value);
    });
  });
}

function getSelectedPaymentMethod(container) {
  const selected = container.querySelector('input[name="answer[payment_method]"]:checked');
  return selected ? selected.value : null;
}

function showPaymentMethod(container, method) {
  if (!container || !method) return;

  // Hide all payment containers first
  const paymentContainers = container.querySelectorAll('[data-payment-method]');
  paymentContainers.forEach(paymentContainer => {
    paymentContainer.style.display = 'none';
  });

  // Show selected payment method
  const selectedContainer = container.querySelector(`[data-payment-method="${method}"]`);
  if (selectedContainer) {
    selectedContainer.style.display = 'block';
    console.log('Showing payment method:', method);
  } else {
    console.warn('Payment method container not found:', method);
  }
}

// Stripe Payment Integration
function initializeStripePayment(container) {
  try {
    // Get configuration from the container
    const config = getPaymentConfig(container);
    if (!config || !config.stripe_publishable_key) {
      console.warn('No Stripe configuration found, using manual input');
      showManualCardInput(container);
      return;
    }

    const stripe = Stripe(config.stripe_publishable_key);
    const elements = stripe.elements();

    // Create card element
    const cardElement = elements.create('card', {
      style: {
        base: {
          fontSize: '16px',
          color: '#424770',
          '::placeholder': {
            color: '#aab7c4',
          },
        },
      },
    });

    // Mount card element
    const cardElementContainer = container.querySelector('.stripe-card-element');
    if (cardElementContainer) {
      cardElement.mount(cardElementContainer);
      console.log('Stripe card element mounted successfully');
    } else {
      console.error('Stripe card mount point not found');
      return;
    }

    // Handle form submission
    const form = container.closest('form');
    if (form) {
      form.addEventListener('submit', async (event) => {
        const selectedMethod = getSelectedPaymentMethod(container);
        if (selectedMethod === 'credit_card') {
          event.preventDefault();
          
          const { paymentMethod, error } = await stripe.createPaymentMethod({
            type: 'card',
            card: cardElement,
          });

          if (error) {
            displayPaymentError(container, error.message);
          } else {
            // Add payment method ID to form
            const hiddenInput = document.createElement('input');
            hiddenInput.type = 'hidden';
            hiddenInput.name = 'answer[payment_method_id]';
            hiddenInput.value = paymentMethod.id;
            form.appendChild(hiddenInput);
            
            form.submit();
          }
        }
      });
    }
  } catch (error) {
    console.error('Stripe initialization error:', error);
    showManualCardInput(container);
  }
}

// PayPal Payment Integration
function initializePayPalPayment(container) {
  try {
    const config = getPaymentConfig(container);
    if (!config || !config.amount) {
      console.warn('No PayPal configuration found');
      return;
    }

    const paypalContainer = container.querySelector('.paypal-button-container');
    if (!paypalContainer) {
      console.warn('PayPal button container not found');
      return;
    }

    paypal.Buttons({
      createOrder: function(data, actions) {
        return actions.order.create({
          purchase_units: [{
            amount: {
              value: config.amount.toString(),
              currency_code: config.currency || 'USD'
            },
            description: config.description || 'Payment'
          }]
        });
      },
      onApprove: function(data, actions) {
        return actions.order.capture().then(function(details) {
          // Add payment confirmation to form
          const hiddenInput = document.createElement('input');
          hiddenInput.type = 'hidden';
          hiddenInput.name = 'answer[payment_confirmation]';
          hiddenInput.value = JSON.stringify(details);
          
          const form = container.closest('form');
          if (form) {
            form.appendChild(hiddenInput);
            form.submit();
          }
        });
      },
      onError: function(err) {
        console.error('PayPal Error:', err);
        displayPaymentError(container, 'Payment failed. Please try again.');
      }
    }).render(paypalContainer);

    console.log('PayPal buttons initialized');
  } catch (error) {
    console.error('PayPal initialization error:', error);
  }
}

// Get payment configuration from container data attributes
function getPaymentConfig(container) {
  // Look for configuration in various places
  const configElement = container.querySelector('[data-payment-config]');
  if (configElement) {
    try {
      return JSON.parse(configElement.dataset.paymentConfig || '{}');
    } catch (e) {
      console.warn('Failed to parse payment config:', e);
    }
  }

  // Fallback to individual data attributes
  return {
    amount: parseFloat(container.dataset.amount || 0),
    currency: container.dataset.currency || 'USD',
    stripe_publishable_key: container.dataset.stripeKey || 'pk_test_demo',
    description: container.dataset.description || 'Payment'
  };
}

// Manual card input fallback
function showManualCardInput(container) {
  const cardContainer = container.querySelector('.stripe-payment-container');
  if (cardContainer) {
    cardContainer.innerHTML = `
      <div class="border border-gray-200 rounded-lg p-4">
        <label class="block text-sm font-medium text-gray-700 mb-2">Card Number</label>
        <input type="text" class="w-full border border-gray-300 rounded-md p-2" 
               placeholder="1234 5678 9012 3456" maxlength="19" 
               name="answer[card_number]" required>
        
        <div class="grid grid-cols-2 gap-4 mt-4">
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">Expiry Date</label>
            <input type="text" class="w-full border border-gray-300 rounded-md p-2" 
                   placeholder="MM/YY" maxlength="5" 
                   name="answer[expiry_date]" required>
          </div>
          <div>
            <label class="block text-sm font-medium text-gray-700 mb-2">CVC</label>
            <input type="text" class="w-full border border-gray-300 rounded-md p-2" 
                   placeholder="123" maxlength="4" 
                   name="answer[cvc]" required>
          </div>
        </div>
      </div>
    `;
    cardContainer.style.display = 'block';
  }
}

// Payment error handling
function displayPaymentError(container, message) {
  const errorContainer = container.querySelector('.payment-error');
  if (errorContainer) {
    errorContainer.textContent = message;
    errorContainer.style.display = 'block';
  }
}

// Export for global use
window.PaymentIntegration = {
  initializePaymentContainers,
  showPaymentMethod,
  initializeStripePayment,
  initializePayPalPayment,
  showManualCardInput,
  displayPaymentError
};