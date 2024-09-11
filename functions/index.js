const functions = require('firebase-functions');
const admin = require('firebase-admin');
admin.initializeApp();

exports.checkTimeLimits = functions.pubsub.schedule('every 1 minutes').onRun(async (context) => {
  const now = new Date();
  const today = now.toLocaleDateString('en-US', { weekday: 'long' });

  const parentsSnapshot = await admin.firestore().collection('parents').get();

  parentsSnapshot.forEach(async (parentDoc) => {
    const childrenSnapshot = await parentDoc.ref.collection('children').get();

    childrenSnapshot.forEach(async (childDoc) => {
      const usageLimits = childDoc.data().usageLimit?.dailyLimits || {};
      const lastAccessTime = childDoc.data().lastAccessTime.toDate();

      // Example logic: Calculate elapsed time since last access and check limits
      const elapsedTime = Math.floor((now - lastAccessTime) / 60000); // Time in minutes
      const dailyLimit = usageLimits[today] || 0;

      if (elapsedTime >= dailyLimit) {
        // Block device
        await childDoc.ref.update({ deviceBlocked: true });

        // Send notification
        const payload = {
          notification: {
            title: 'Time Limit Reached',
            body: 'The time limit for using the device has been reached.',
          }
        };
        await admin.messaging().sendToDevice(childDoc.data().deviceToken, payload);
      }
    });
  });
});
