import { randomString, sha256 } from "./pkce";

const domain = import.meta.env.VITE_COGNITO_DOMAIN_FULL as string | undefined;
const clientId = import.meta.env.VITE_COGNITO_CLIENT_ID as string | undefined;
const redirectUri = import.meta.env.VITE_COGNITO_REDIRECT_URI as string | undefined;
const logoutUri = import.meta.env.VITE_COGNITO_LOGOUT_URI as string | undefined;

const LS_VERIFIER = "pkce_verifier";
const LS_TOKENS = "tokens";

type CognitoConfig = {
    domain: string;
    clientId: string;
    redirectUri: string;
    logoutUri: string;
};

export type Tokens = {
    access_token: string;
    id_token: string;
    refresh_token?: string;
    token_type: string;
    expires_in: number;
};

function getCognitoConfig(): CognitoConfig {
    if (!domain || !clientId || !redirectUri || !logoutUri) {
        throw new Error("Cognito env not set (VITE_COGNITO_DOMAIN_FULL / VITE_COGNITO_CLIENT_ID / VITE_COGNITO_REDIRECT_URI / VITE_COGNITO_LOGOUT_URI)");
    }

    return { domain, clientId, redirectUri, logoutUri };
}

export function isCognitoConfigured() {
    return Boolean(domain && clientId && redirectUri && logoutUri);
}

export function getTokens(): Tokens | null {
    const raw = localStorage.getItem(LS_TOKENS);
    if (!raw) return null;
    try {
        return JSON.parse(raw) as Tokens;
    } catch {
        return null;
    }
}

export function setTokens(tokens: Tokens | null) {
    if (!tokens) localStorage.removeItem(LS_TOKENS);
    else localStorage.setItem(LS_TOKENS, JSON.stringify(tokens));
}

export function getAccessToken(): string | null {
    return getTokens()?.access_token ?? null;
}

export async function loginRedirect() {
    const config = getCognitoConfig();

    const verifier = randomString(64);
    const challenge = await sha256(verifier);

    localStorage.setItem(LS_VERIFIER, verifier);

    const url = new URL(`${config.domain}/oauth2/authorize`);
    url.searchParams.set("client_id", config.clientId);
    url.searchParams.set("response_type", "code");
    url.searchParams.set("scope", "openid email profile");
    url.searchParams.set("redirect_uri", config.redirectUri);
    url.searchParams.set("code_challenge_method", "S256");
    url.searchParams.set("code_challenge", challenge);

    window.location.assign(url.toString());
}

export async function exchangeCodeForTokens(code: string) {
    const config = getCognitoConfig();

    const verifier = localStorage.getItem(LS_VERIFIER);
    if (!verifier) throw new Error("Missing PKCE verifier (refresh during login?)");

    const body = new URLSearchParams();
    body.set("grant_type", "authorization_code");
    body.set("client_id", config.clientId);
    body.set("code", code);
    body.set("redirect_uri", config.redirectUri);
    body.set("code_verifier", verifier);

    const res = await fetch(`${config.domain}/oauth2/token`, {
        method: "POST",
        headers: { "Content-Type": "application/x-www-form-urlencoded" },
        body: body.toString(),
    });

    if (!res.ok) throw new Error(`Token exchange failed: ${res.status} ${await res.text()}`);

    const tokens = (await res.json()) as Tokens;
    setTokens(tokens);
    localStorage.removeItem(LS_VERIFIER);
    return tokens;
}

export function logoutRedirect() {
    // local logout
    setTokens(null);

    if (!domain || !clientId || !logoutUri) {
        // if not configured, just reload
        window.location.assign("/");
        return;
    }

    const url = new URL(`${domain}/logout`);
    url.searchParams.set("client_id", clientId);
    url.searchParams.set("logout_uri", logoutUri);
    window.location.assign(url.toString());
}