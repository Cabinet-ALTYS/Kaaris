import { ApiError, upstreamJSON } from "./http.mjs";

const messages = {
  reminder: [
    "Ta séance approche. Prépare ton sac.",
    "Ton créneau est posé. File préparer ton sac.",
    "T’as bloqué ce créneau. On ne le laisse pas filer, bordel."
  ],
  check_in: [
    "Tu es arrivé à ta séance ? Fais ton point.",
    "T’en es où ? Fais ton point à la salle.",
    "Allez, fais ton point. T’es arrivé à la salle ou tu reportes ?"
  ],
  missed: [
    "Tu veux replanifier ta séance ? Choisis ton prochain créneau.",
    "T’as raté ce créneau. Reprends la main et replanifie.",
    "T’avais fixé un objectif. Ça arrive de rater, bordel. Replanifie."
  ],
  done: [
    "Séance terminée. Note ce que tu veux retenir.",
    "Séance faite. Coche-la et prépare la suite.",
    "Bien joué. T’as tenu ton engagement."
  ]
};

export function createCoach(origin, fetcher = fetch) {
  let busy = false;
  return async (body) => {
    if (!Object.hasOwn(messages, body.event) ||
        !Number.isInteger(body.insultLevel) || body.insultLevel < 0 || body.insultLevel > 4 ||
        !Number.isInteger(body.egoLevel) || body.egoLevel < 0 || body.egoLevel > 4) {
      throw new ApiError(400, "invalid_coach_request");
    }

    const variants = messages[body.event];
    const consent = body.bluntToneConsented === true;
    const valid = [0];
    if (consent && (body.insultLevel > 0 || body.egoLevel > 0)) valid.push(1);
    if (consent && body.insultLevel >= 3 && body.egoLevel >= 2) valid.push(2);

    let selected = valid.at(-1);
    let source = "template";
    if (origin && !busy && valid.length > 1) {
      busy = true;
      try {
        const reply = await upstreamJSON(fetcher, new URL("/v1/chat/completions", origin), {
          method: "POST",
          headers: { "Content-Type": "application/json" },
          body: JSON.stringify({
            messages: [{
              role: "system",
              content: "Sélectionne la variante française adaptée au niveau demandé. Réponds uniquement avec son indice entier."
            }, {
              role: "user",
              content: JSON.stringify({
                event: body.event,
                directness: body.insultLevel,
                commitment: body.egoLevel,
                choices: valid.map((index) => ({ index, text: variants[index] }))
              })
            }],
            chat_template_kwargs: { enable_thinking: false },
            max_tokens: 12,
            temperature: 0
          })
        }, "inference_unavailable", 6000);
        const raw = reply.body?.choices?.[0]?.message?.content?.trim();
        if (reply.ok && /^[0-2]$/.test(raw) && valid.includes(Number(raw))) {
          selected = Number(raw);
          source = "model";
        }
      } catch {
        // Les relances continuent à fonctionner lorsque l’inférence est indisponible.
      } finally {
        busy = false;
      }
    }

    return { text: variants[selected], source };
  };
}
