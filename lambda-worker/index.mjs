import { DynamoDBClient } from '@aws-sdk/client-dynamodb';
import { DynamoDBDocumentClient, PutCommand, UpdateCommand } from '@aws-sdk/lib-dynamodb';
import { SQSClient, SendMessageCommand } from '@aws-sdk/client-sqs';

const dynamoClient = new DynamoDBClient({ region: 'eu-west-1' });
const dynamoDB = DynamoDBDocumentClient.from(dynamoClient);
const sqs = new SQSClient({ region: 'eu-west-1' });

const ORDERS_TABLE = process.env.DYNAMODB_TABLE_NAME;
const LONG_TASKS_QUEUE = process.env.LONG_TASKS_QUEUE_URL;

export const handler = async (event) => {
  console.log('📦 Lambda Worker triggered');
  console.log('Event records:', event.Records?.length || 0);

  const results = [];

  // Traiter chaque message SQS
  for (const record of event.Records) {
    try {
      const message = JSON.parse(record.body);
      console.log('📨 Processing message:', message.sessionId);

      const result = await processOrder(message);
      results.push({ success: true, orderId: result.orderId });

    } catch (error) {
      console.error('❌ Error processing record:', error);
      results.push({ success: false, error: error.message });
      // Ne pas throw - permet de traiter les autres messages
    }
  }

  console.log('✅ Batch processing complete:', results);
  return { statusCode: 200, body: JSON.stringify(results) };
};

async function processOrder(orderMessage) {
  const orderId = `ord_${Date.now()}_${Math.random().toString(36).substr(2, 9)}`;
  const timestamp = new Date().toISOString();

  console.log('🆕 Creating order:', orderId);

  // 1. Créer l'ordre dans DynamoDB
  const orderItem = {
    orderId: orderId,
    eventId: orderMessage.eventId,
    sessionId: orderMessage.sessionId,
    customerEmail: orderMessage.customerEmail,
    customerName: orderMessage.customerName,
    customerId: orderMessage.customerId,
    amountTotal: orderMessage.amountTotal,
    currency: orderMessage.currency,
    paymentStatus: orderMessage.paymentStatus,
    orderStatus: 'pending',
    createdAt: timestamp,
    updatedAt: timestamp,
    metadata: orderMessage.metadata || {},
    logs: [
      {
        timestamp: timestamp,
        status: 'received',
        message: 'Order received from Stripe webhook'
      }
    ]
  };

  const putCommand = new PutCommand({
    TableName: ORDERS_TABLE,
    Item: orderItem,
  });

  await dynamoDB.send(putCommand);
  console.log('✅ Order saved to DynamoDB');

  // 2. Déterminer si c'est un traitement long
  const needsLongProcessing = shouldProcessLong(orderItem);

  if (needsLongProcessing) {
    console.log('⏳ Order needs long processing, sending to long tasks queue');
    
    // Envoyer vers la queue des tâches longues
    await sendToLongTasksQueue(orderItem);
    
    // Update status
    await updateOrderStatus(orderId, 'queued_for_processing', 'Queued for packaging and shipping');
  } else {
    console.log('⚡ Order can be completed immediately');
    
    // Traitement simple (pas de produits physiques par exemple)
    await updateOrderStatus(orderId, 'completed', 'Order completed - digital product');
  }

  return { orderId, status: needsLongProcessing ? 'queued' : 'completed' };
}

function shouldProcessLong(order) {
  // Pour ce projet : TOUS les ordres ont besoin de packaging/shipping
  // Dans un vrai projet, on vérifierait le type de produit
  return true;
  
  // Exemple de logique plus complexe :
  // return order.amountTotal > 1000 || order.metadata.requiresShipping === true;
}

async function sendToLongTasksQueue(order) {
  const message = {
    orderId: order.orderId,
    sessionId: order.sessionId,
    customerEmail: order.customerEmail,
    customerName: order.customerName,
    amountTotal: order.amountTotal,
    currency: order.currency,
    createdAt: order.createdAt,
  };

  const command = new SendMessageCommand({
    QueueUrl: LONG_TASKS_QUEUE,
    MessageBody: JSON.stringify(message),
    MessageAttributes: {
      orderId: {
        DataType: 'String',
        StringValue: order.orderId,
      },
      taskType: {
        DataType: 'String',
        StringValue: 'packaging_and_shipping',
      },
    },
  });

  const result = await sqs.send(command);
  console.log('✅ Sent to long tasks queue:', result.MessageId);
}

async function updateOrderStatus(orderId, status, message) {
  const timestamp = new Date().toISOString();
  
  const command = new UpdateCommand({
    TableName: ORDERS_TABLE,
    Key: { orderId },
    UpdateExpression: 'SET orderStatus = :status, updatedAt = :timestamp, logs = list_append(logs, :log)',
    ExpressionAttributeValues: {
      ':status': status,
      ':timestamp': timestamp,
      ':log': [{
        timestamp: timestamp,
        status: status,
        message: message,
      }],
    },
  });

  await dynamoDB.send(command);
  console.log(`✅ Order ${orderId} status updated to: ${status}`);
}