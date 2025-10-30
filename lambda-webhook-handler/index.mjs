import Stripe from 'stripe';
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';

const stripe = new Stripe(process.env.STRIPE_SECRET_KEY);
const sqs = new SQSClient({ region: process.env.AWS_REGION || 'eu-west-1' });

export const handler = async (event) => {
  console.log('Webhook received:', JSON.stringify(event, null, 2));

  try {
    // 1. Parse le body
    const body = typeof event.body === 'string' ? event.body : JSON.stringify(event.body);
    const signature = event.headers['stripe-signature'] || event.headers['Stripe-Signature'];

    if (!signature) {
      console.error('No Stripe signature found');
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'No signature' }),
      };
    }

    // 2. Valider la signature Stripe
    let stripeEvent;
    try {
      stripeEvent = stripe.webhooks.constructEvent(
        body,
        signature,
        process.env.STRIPE_WEBHOOK_SECRET
      );
    } catch (err) {
      console.error('❌ Webhook signature verification failed:', err.message);
      return {
        statusCode: 400,
        body: JSON.stringify({ error: 'Invalid signature' }),
      };
    }

    console.log('✅ Event type:', stripeEvent.type);
    console.log('📦 Event ID:', stripeEvent.id);

    // 3. Traiter selon le type d'événement
    switch (stripeEvent.type) {
      case 'checkout.session.completed':
        await handleCheckoutCompleted(stripeEvent.data.object, stripeEvent.id);
        break;
      
      case 'payment_intent.succeeded':
        await handlePaymentSucceeded(stripeEvent.data.object, stripeEvent.id);
        break;
      
      case 'payment_intent.payment_failed':
        console.log('❌ Payment failed:', stripeEvent.data.object.id);
        // Log détaillé dans CloudWatch
        console.log(JSON.stringify(stripeEvent.data.object, null, 2));
        break;
      
      default:
        console.log('ℹ️  Unhandled event type:', stripeEvent.type);
    }

    // 4. Log structuré pour CloudWatch (audit trail)
    console.log('📊 EVENT_LOG:', JSON.stringify({
      eventId: stripeEvent.id,
      eventType: stripeEvent.type,
      timestamp: new Date().toISOString(),
      objectId: stripeEvent.data.object.id,
      amount: stripeEvent.data.object.amount_total || stripeEvent.data.object.amount,
      currency: stripeEvent.data.object.currency,
    }));

    return {
      statusCode: 200,
      body: JSON.stringify({ received: true }),
    };

  } catch (error) {
    console.error('❌ Error processing webhook:', error);
    return {
      statusCode: 500,
      body: JSON.stringify({ error: error.message }),
    };
  }
};

async function handleCheckoutCompleted(session, eventId) {
  console.log('✅ Checkout completed:', session.id);

  // Créer le message pour SQS
  const orderMessage = {
    eventId: eventId,
    eventType: 'order.created',
    sessionId: session.id,
    customerId: session.customer,
    customerEmail: session.customer_details?.email,
    customerName: session.customer_details?.name,
    amountTotal: session.amount_total,
    currency: session.currency,
    paymentStatus: session.payment_status,
    timestamp: new Date().toISOString(),
    metadata: session.metadata || {},
  };

  console.log('📤 Sending to SQS:', JSON.stringify(orderMessage, null, 2));

  // Envoyer vers SQS
  try {
    const sqsCommand = new SendMessageCommand({
      QueueUrl: process.env.SQS_QUEUE_URL,
      MessageBody: JSON.stringify(orderMessage),
      MessageAttributes: {
        eventType: {
          DataType: 'String',
          StringValue: 'order.created',
        },
        eventId: {
          DataType: 'String',
          StringValue: eventId,
        },
      },
    });

    const result = await sqs.send(sqsCommand);
    console.log('✅ Message sent to SQS:', result.MessageId);
  } catch (error) {
    console.error('❌ Failed to send to SQS:', error);
    throw error;
  }
}

async function handlePaymentSucceeded(paymentIntent, eventId) {
  console.log('✅ Payment succeeded:', paymentIntent.id);
  console.log('💰 Amount:', paymentIntent.amount, paymentIntent.currency);
  
  // Log détaillé dans CloudWatch
  console.log('📊 PAYMENT_LOG:', JSON.stringify({
    eventId: eventId,
    paymentIntentId: paymentIntent.id,
    amount: paymentIntent.amount,
    currency: paymentIntent.currency,
    status: paymentIntent.status,
    timestamp: new Date().toISOString(),
  }));
}
