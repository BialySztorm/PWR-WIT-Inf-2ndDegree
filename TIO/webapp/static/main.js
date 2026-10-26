const instanceSelect = document.getElementById("instance-select");
const methodSelect = document.getElementById("method-select");
const viewSelect = document.getElementById("view-select");
const playBtn = document.getElementById("play-btn");
const costSummary = document.getElementById("cost-summary");
const costTableBody = document.querySelector("#cost-table tbody");
const plotsSection = document.getElementById("plots-section");
const routePlot = document.getElementById("route-plot");
const lightbox = document.getElementById("lightbox");
const lightboxImg = document.getElementById("lightbox-img");

let currentInstance = null;
let currentRoute = null;
let animTraceIndex = null;

async function getJSON(url) {
    const res = await fetch(url);
    if (!res.ok) throw new Error(`${url}: ${res.status}`);
    return res.json();
}

function terrainGrid(instance) {
    const { width, height } = instance.grid;
    const z = [];
    for (let y = 0; y < height; y++) {
        const row = [];
        for (let x = 0; x < width; x++) {
            row.push(instance.terrain[y * width + x]);
        }
        z.push(row);
    }
    return z;
}

// Distinct colors cycled across flights (the stretches between battery
// swaps) so consecutive flights are visually distinguishable on the plot.
const FLIGHT_COLORS = [
    "#ff6b6b", "#4fa3ff", "#4fd18b", "#ffd166", "#c77dff",
    "#06d6a0", "#f78c6b", "#80ffdb", "#ff8fab", "#9d4edd",
];

// Splits `route.order` into per-flight segments at each battery swap,
// splicing the base/takeoff point in at both ends of the split so segments
// still connect visually. `route.order` only holds the surveyed cells, not
// the physical flight back to base, so without the splice the line would
// jump straight between two distant cells instead of showing the detour.
function routeSegments(instance, route) {
    const base = instance.takeoff.candidates[0];
    const swapSteps = new Set(route.cost.swap_before_step || []);
    const segments = [[]];
    route.order.forEach((c, i) => {
        if (swapSteps.has(i)) {
            segments[segments.length - 1].push([base.x, base.y]);
            segments.push([[base.x, base.y]]);
        }
        segments[segments.length - 1].push(c);
    });
    const swapXs = segments.slice(1).map(() => base.x);
    const swapYs = segments.slice(1).map(() => base.y);
    return { segments, swapXs, swapYs };
}

// Concatenates all flight segments back into one continuous path, used by
// the animation overlay (which always needs the full route in order,
// regardless of how the colored segments are grouped below).
function flattenSegments(segments) {
    const xs = [];
    const ys = [];
    for (const seg of segments) {
        for (const c of seg) {
            xs.push(c[0]);
            ys.push(c[1]);
        }
    }
    return { xs, ys };
}

// Groups flight segments by `index % FLIGHT_COLORS.length` into one Plotly
// trace per color, joined with `null` gaps between non-adjacent segments
// (so Plotly doesn't draw a connecting line between unrelated flights).
// This keeps the trace count bounded by the palette size no matter how many
// battery swaps a route has (some real-world routes swap on nearly every
// step).
function colorGroupedTraces(segments, project) {
    const groups = FLIGHT_COLORS.map(() => ({ xs: [], ys: [], zs: [] }));
    segments.forEach((seg, i) => {
        const g = groups[i % FLIGHT_COLORS.length];
        if (g.xs.length > 0) {
            g.xs.push(null);
            g.ys.push(null);
            g.zs.push(null);
        }
        for (const c of seg) {
            const p = project(c);
            g.xs.push(p[0]);
            g.ys.push(p[1]);
            g.zs.push(p[2]);
        }
    });
    return groups
        .map((g, idx) => ({ ...g, color: FLIGHT_COLORS[idx] }))
        .filter((g) => g.xs.length > 0);
}

function heightAt(instance, x, y) {
    return instance.terrain[y * instance.grid.width + x];
}

function renderCostSummary(route) {
    const c = route.cost;
    costSummary.textContent =
        `method=${route.method} config=${route.config_id} | ` +
        `total=${c.total.toFixed(1)}s flight_time=${c.flight_time_s.toFixed(1)}s ` +
        `turn_penalty=${c.turn_penalty.toFixed(2)} climb_cost=${c.climb_cost.toFixed(1)} ` +
        `battery_swaps=${c.battery_swaps} violations=${c.violations.toFixed(1)} ` +
        `feasible=${c.feasible}`;
}

async function renderCostTable(instanceName, methods) {
    costTableBody.innerHTML = "";
    const routes = await Promise.all(
        methods.map((m) => getJSON(`/api/route/${instanceName}/${m}`))
    );
    for (const route of routes) {
        const c = route.cost;
        const tr = document.createElement("tr");
        if (route.method === methodSelect.value) {
            tr.classList.add("active-method");
        }
        const feasibleClass = c.feasible ? "feasible-true" : "feasible-false";
        tr.innerHTML =
            `<td>${route.method}</td>` +
            `<td>${route.config_id}</td>` +
            `<td>${c.total.toFixed(1)}</td>` +
            `<td>${c.flight_time_s.toFixed(1)}</td>` +
            `<td>${c.turn_penalty.toFixed(2)}</td>` +
            `<td>${c.climb_cost.toFixed(1)}</td>` +
            `<td>${c.battery_swaps}</td>` +
            `<td>${c.violations.toFixed(1)}</td>` +
            `<td class="${feasibleClass}">${c.feasible}</td>`;
        costTableBody.appendChild(tr);
    }
}

function render2D(instance, route) {
    const z = terrainGrid(instance);
    const { segments, swapXs, swapYs } = routeSegments(instance, route);
    const heatmap = {
        z,
        type: "heatmap",
        colorscale: "Earth",
        showscale: true,
    };
    const flightTraces = colorGroupedTraces(segments, (c) => [c[0], c[1], null]).map((g) => ({
        x: g.xs,
        y: g.ys,
        mode: "lines+markers",
        type: "scatter",
        line: { color: g.color, width: 2 },
        marker: { size: 4, color: g.color },
        showlegend: false,
        hoverinfo: "x+y",
    }));
    const swapTrace = {
        x: swapXs,
        y: swapYs,
        mode: "markers",
        type: "scatter",
        marker: { symbol: "star", size: 14, color: "gold", line: { color: "#0b0d10", width: 1 } },
        name: "battery swap",
    };
    const animTrace = { x: [], y: [], mode: "lines+markers", type: "scatter", line: { color: "white", width: 3 }, marker: { size: 5, color: "white" }, name: "animation" };
    animTraceIndex = 1 + flightTraces.length + 1;
    Plotly.newPlot(routePlot, [heatmap, ...flightTraces, swapTrace, animTrace], {
        title: `${instance.name} — ${route.method}`,
        xaxis: { title: "x (cell)" },
        yaxis: { title: "y (cell)" },
    });
}

function render3D(instance, route) {
    const { width, height } = instance.grid;
    const z = terrainGrid(instance);
    const xAxis = Array.from({ length: width }, (_, i) => i);
    const yAxis = Array.from({ length: height }, (_, i) => i);
    const { segments, swapXs, swapYs } = routeSegments(instance, route);
    const swapZs = swapXs.map((x, i) => heightAt(instance, x, swapYs[i]) + 5);

    const surface = {
        x: xAxis,
        y: yAxis,
        z,
        type: "surface",
        colorscale: "Earth",
        opacity: 0.9,
        showscale: true,
    };
    const flightTraces = colorGroupedTraces(segments, (c) => [c[0], c[1], heightAt(instance, c[0], c[1]) + 5]).map((g) => ({
        x: g.xs,
        y: g.ys,
        z: g.zs,
        mode: "lines+markers",
        type: "scatter3d",
        line: { color: g.color, width: 4 },
        marker: { size: 2, color: g.color },
        showlegend: false,
        hoverinfo: "x+y+z",
    }));
    const swapTrace = {
        x: swapXs,
        y: swapYs,
        z: swapZs,
        mode: "markers",
        type: "scatter3d",
        marker: { symbol: "diamond", size: 6, color: "gold", line: { color: "#0b0d10", width: 1 } },
        name: "battery swap",
    };
    const animTrace = { x: [], y: [], z: [], mode: "lines+markers", type: "scatter3d", line: { color: "white", width: 5 }, marker: { size: 3, color: "white" }, name: "animation" };
    animTraceIndex = 1 + flightTraces.length + 1;
    Plotly.newPlot(routePlot, [surface, ...flightTraces, swapTrace, animTrace], {
        title: `${instance.name} — ${route.method}`,
        scene: { xaxis: { title: "x" }, yaxis: { title: "y" }, zaxis: { title: "elevation (m)" } },
    });
}

function render() {
    if (!currentInstance || !currentRoute) return;
    renderCostSummary(currentRoute);
    if (viewSelect.value === "3d") {
        render3D(currentInstance, currentRoute);
    } else {
        render2D(currentInstance, currentRoute);
    }
}

async function playAnimation() {
    if (!currentInstance || !currentRoute || animTraceIndex === null) return;
    const is3D = viewSelect.value === "3d";
    const { segments } = routeSegments(currentInstance, currentRoute);
    const { xs: fullXs, ys: fullYs } = flattenSegments(segments);
    const n = fullXs.length;

    for (let step = 1; step <= n; step++) {
        const xs = fullXs.slice(0, step);
        const ys = fullYs.slice(0, step);
        if (is3D) {
            const zs = xs.map((x, i) => heightAt(currentInstance, x, ys[i]) + 5);
            Plotly.restyle(routePlot, { x: [xs], y: [ys], z: [zs] }, [animTraceIndex]);
        } else {
            Plotly.restyle(routePlot, { x: [xs], y: [ys] }, [animTraceIndex]);
        }
        await new Promise((r) => setTimeout(r, 15));
    }
}

async function loadInstance(name) {
    currentInstance = await getJSON(`/api/instance/${name}`);
    const methods = await getJSON(`/api/routes/${name}`);
    methodSelect.innerHTML = "";
    for (const m of methods) {
        const opt = document.createElement("option");
        opt.value = m;
        opt.textContent = m;
        methodSelect.appendChild(opt);
    }
    if (methods.length > 0) {
        await loadRoute(name, methods[0]);
    }
    await renderCostTable(name, methods);

    const plots = await getJSON(`/api/plots-for/${name}`);
    plotsSection.innerHTML = "";
    for (const p of plots) {
        const figure = document.createElement("figure");
        const img = document.createElement("img");
        img.src = `/api/plots/${p}`;
        img.alt = p;
        const caption = document.createElement("figcaption");
        const filename = p.split("/").pop().replace(".png", "");
        caption.textContent = filename.replace(/_/g, " ");
        img.addEventListener("click", () => openLightbox(img.src, img.alt));
        figure.appendChild(img);
        figure.appendChild(caption);
        plotsSection.appendChild(figure);
    }
}

function openLightbox(src, alt) {
    lightboxImg.src = src;
    lightboxImg.alt = alt;
    lightbox.classList.remove("hidden");
}

function closeLightbox() {
    lightbox.classList.add("hidden");
    lightboxImg.src = "";
}

lightbox.addEventListener("click", closeLightbox);
window.addEventListener("keydown", (e) => {
    if (e.key === "Escape") closeLightbox();
});

async function loadRoute(instanceName, method) {
    currentRoute = await getJSON(`/api/route/${instanceName}/${method}`);
    render();
    for (const tr of costTableBody.children) {
        tr.classList.toggle("active-method", tr.firstChild.textContent === method);
    }
}

instanceSelect.addEventListener("change", () => loadInstance(instanceSelect.value));
methodSelect.addEventListener("change", () => loadRoute(instanceSelect.value, methodSelect.value));
viewSelect.addEventListener("change", render);
playBtn.addEventListener("click", playAnimation);

// Plotly sizes itself to the container once, at render time - it never
// re-measures on its own, so without this the chart keeps its original
// pixel width and forces a horizontal scrollbar whenever the window (or
// the grid column it sits in) is resized smaller.
let resizeTimer = null;
window.addEventListener("resize", () => {
    clearTimeout(resizeTimer);
    resizeTimer = setTimeout(() => Plotly.Plots.resize(routePlot), 100);
});

(async function init() {
    const instances = await getJSON("/api/instances");
    for (const name of instances) {
        const opt = document.createElement("option");
        opt.value = name;
        opt.textContent = name;
        instanceSelect.appendChild(opt);
    }
    if (instances.length > 0) {
        await loadInstance(instances[0]);
    }
})();
