import {createRemoteJWKSet, jwtVerify} from "jose";

const PROJECT_ID = "semaia";
const JWKS_URL =
    "https://www.googleapis.com/service_accounts/v1/jwk/securetoken@system.gserviceaccount.com";

// Cached JWKS fetcher
const JWKS = createRemoteJWKSet(new URL(JWKS_URL));

export const handler = async (event) => {
    const req = event.Records[0].cf.request;
    const authz = req.headers.authorization?.[0]?.value || "";

    if (!authz.startsWith("Bearer ")) {
        return deny(401, "Missing bearer token");
    }

    const token = authz.slice(7);

    try {
        const {payload} = await jwtVerify(
            token,
            JWKS, {
                issuer: `https://securetoken.google.com/${PROJECT_ID}`,
                audience: PROJECT_ID,
            }
        );

        // Pass safe user claims downstream
        req.headers["x-user-uid"] = [
            {key: "x-user-uid", value: payload.sub || ""},
        ];

        if (payload.email) {
            req.headers["x-user-email"] = [
                {key: "x-user-email", value: String(payload.email)},
            ];
        }

        return req;
    } catch (e) {
        console.log("JWT verify failed:", e);
        return deny(401, "Invalid or expired token");
    }
};

function deny(status, msg) {
    return {
        status: String(status),
        statusDescription: msg,
        body: JSON.stringify({error: msg}),
        headers: {
            "content-type": [
                {key: "Content-Type", value: "application/json"},
            ],
        },
    };
}
