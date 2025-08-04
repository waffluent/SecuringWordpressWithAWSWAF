'use strict';
const crypto = require('crypto');

function ipToLong(ip) {
    return ip.split('.').reduce((acc, oct) => (acc << 8) + parseInt(oct, 10), 0) >>> 0;
}

function ipInCidr(ip, cidr) {
    if (ip.includes(':')) {
        return ipInCidr6(ip, cidr); // Placeholder if IPv6 handling is needed
    }
    const [range, bits = '32'] = cidr.split('/');
    const mask = ~(2 ** (32 - Number(bits)) - 1);
    return (ipToLong(ip) & mask) === (ipToLong(range) & mask);
}

exports.handler = async (event) => {
    const secret = process.env.SHARED_SECRET;
    const cfCidrs = JSON.parse(process.env.CF_ORIGIN_CIDRS);

    let nonce, userAgent;

    // CLOUD FRONT MODE
    if (event.Records?.[0]?.cf) {
        const cfEvent = event.Records[0].cf;
        const request = cfEvent.request;
        const response = cfEvent.response;

        // Verify IP is in CloudFront MPL
        const sourceIp = request.clientIp;
        const ipMatch = cfCidrs.some(cidr => ipInCidr(sourceIp, cidr));

        if (!ipMatch) {
            response.status = '403';
            response.statusDescription = 'Forbidden - Not CloudFront';
            response.body = 'Forbidden';
            return response;
        }

        // Nonce from AWS (non-spoofable)
        nonce = cfEvent.config.requestId;
        userAgent = request.headers['user-agent']?.[0]?.value || '';

        const timestamp = Math.floor(Date.now() / 1000);
        const payload = `${userAgent}|${nonce}|${timestamp}`;
        const hmac = crypto.createHmac('sha256', secret)
                           .update(payload)
                           .digest('base64');

        response.headers['x-aws-pass'] = [
            { key: 'x-aws-pass', value: `${hmac}.${timestamp}.${nonce}` }
        ];

        return response;
    }

    // REGIONAL MODE (no MPL check)
    const request = event;
    userAgent = (event.headers?.['user-agent'] || event.headers?.['User-Agent'] || '');
    nonce = crypto.randomBytes(8).toString('hex');

    const timestamp = Math.floor(Date.now() / 1000);
    const payload = `${userAgent}|${nonce}|${timestamp}`;
    const hmac = crypto.createHmac('sha256', secret)
                       .update(payload)
                       .digest('base64');

    return {
        ...event,
        headers: {
            ...(event.headers || {}),
            'x-aws-pass': `${hmac}.${timestamp}.${nonce}`
        }
    };
};
