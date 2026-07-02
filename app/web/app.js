// O front fala com a API por caminho relativo (/api/...).
// Quem roteia isso para o serviço da API é o nginx (proxy_pass), cujo
// upstream é parametrizável por variável de ambiente no container.
// Assim o mesmo front funciona no docker-compose e no Kubernetes sem recompilar.

const API = "/api/messages";
const $ = (id) => document.getElementById(id);

function setStatus(msg, isError) {
  const el = $("status");
  el.textContent = msg;
  el.className = "status" + (isError ? " error" : "");
}

async function load() {
  try {
    const res = await fetch(API);
    if (!res.ok) throw new Error("HTTP " + res.status);
    const items = await res.json();
    render(items);
    setStatus("");
  } catch (err) {
    setStatus("Não foi possível carregar os recados: " + err.message, true);
  }
}

function render(items) {
  const ul = $("messages");
  ul.innerHTML = "";
  for (const m of items) {
    const li = document.createElement("li");
    li.className = "message";
    const who = document.createElement("strong");
    who.textContent = m.author;
    const body = document.createElement("span");
    body.textContent = " — " + m.content;
    li.append(who, body);
    ul.appendChild(li);
  }
}

$("form").addEventListener("submit", async (e) => {
  e.preventDefault();
  const author = $("author").value.trim();
  const content = $("content").value.trim();
  if (!author || !content) return;
  try {
    const res = await fetch(API, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ author, content }),
    });
    if (!res.ok) throw new Error("HTTP " + res.status);
    $("content").value = "";
    await load();
  } catch (err) {
    setStatus("Falha ao publicar: " + err.message, true);
  }
});

load();
