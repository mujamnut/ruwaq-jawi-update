/**
 * Payment Status Polling Service
 * Service untuk memeriksa status pembayaran ToyyibPay secara berkala
 */

class PaymentStatusService {
  constructor(secretKey, categoryCode) {
    this.secretKey = secretKey;
    this.categoryCode = categoryCode;
    this.toyyibPayApiUrl = 'https://dev.toyyibpay.com'; // Guna dev untuk testing, tukar ke production URL bila ready
  }

  /**
   * Check status pembayaran menggunakan Bill ID
   * @param {string} billId - ID bill dari ToyyibPay
   * @returns {Promise<Object>} Status pembayaran
   */
  async checkPaymentStatus(billId) {
    try {
      const response = await fetch(`${this.toyyibPayApiUrl}/index.php/api/getBillTransactions`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
        },
        body: JSON.stringify({
          userSecretKey: this.secretKey,
          billId: billId
        })
      });

      if (!response.ok) {
        throw new Error(`HTTP error! status: ${response.status}`);
      }

      const data = await response.json();
      return this.parsePaymentStatus(data);
    } catch (error) {
      console.error('Error checking payment status:', error);
      throw error;
    }
  }

  /**
   * Parse response dari ToyyibPay API
   * @param {Object} apiResponse - Response dari ToyyibPay API
   * @returns {Object} Parsed payment status
   */
  parsePaymentStatus(apiResponse) {
    // ToyyibPay biasanya return array of transactions
    if (Array.isArray(apiResponse) && apiResponse.length > 0) {
      const latestTransaction = apiResponse[0]; // Ambil transaction terbaru
      
      return {
        billId: latestTransaction.billId,
        status: latestTransaction.billpaymentStatus, // 1 = Success, 0 = Pending, 3 = Failed
        amount: latestTransaction.billAmount,
        paymentDate: latestTransaction.billpaymentDate,
        transactionId: latestTransaction.billpaymentInvoiceNo,
        paidAmount: latestTransaction.billpaidAmount,
        raw: latestTransaction
      };
    }

    return {
      status: 'pending', // Default status jika tiada transaction
      billId: null,
      amount: null,
      paymentDate: null,
      transactionId: null,
      paidAmount: null,
      raw: apiResponse
    };
  }

  /**
   * Check multiple payment status sekaligus
   * @param {Array<string>} billIds - Array of bill IDs
   * @returns {Promise<Array>} Array of payment statuses
   */
  async checkMultiplePaymentStatus(billIds) {
    const promises = billIds.map(billId => this.checkPaymentStatus(billId));
    return Promise.allSettled(promises);
  }

  /**
   * Determine jika payment sudah success
   * @param {Object} paymentStatus - Status dari checkPaymentStatus
   * @returns {boolean} True jika payment success
   */
  isPaymentSuccessful(paymentStatus) {
    // ToyyibPay: 1 = Success, 0 = Pending, 3 = Failed
    return paymentStatus.status === '1' || paymentStatus.status === 1;
  }

  /**
   * Determine jika payment failed
   * @param {Object} paymentStatus - Status dari checkPaymentStatus
   * @returns {boolean} True jika payment failed
   */
  isPaymentFailed(paymentStatus) {
    // ToyyibPay: 3 = Failed
    return paymentStatus.status === '3' || paymentStatus.status === 3;
  }

  /**
   * Start polling untuk specific bill ID
   * @param {string} billId - Bill ID untuk di-monitor
   * @param {Function} onStatusChange - Callback function bila status berubah
   * @param {number} intervalMs - Interval untuk polling (default 30 seconds)
   * @returns {number} Interval ID untuk stop polling
   */
  startPolling(billId, onStatusChange, intervalMs = 30000) {
    const pollInterval = setInterval(async () => {
      try {
        const status = await this.checkPaymentStatus(billId);
        onStatusChange(status);

        // Stop polling jika payment sudah selesai (success atau failed)
        if (this.isPaymentSuccessful(status) || this.isPaymentFailed(status)) {
          this.stopPolling(pollInterval);
        }
      } catch (error) {
        console.error('Error during polling:', error);
      }
    }, intervalMs);

    return pollInterval;
  }

  /**
   * Stop polling
   * @param {number} intervalId - ID dari interval yang nak di-stop
   */
  stopPolling(intervalId) {
    clearInterval(intervalId);
  }
}

export default PaymentStatusService;
