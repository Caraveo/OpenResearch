import * as THREE from 'three';
import { OrbitControls } from 'three/addons/controls/OrbitControls.js';
import { GLTFLoader } from 'three/addons/loaders/GLTFLoader.js';
import { DRACOLoader } from 'three/addons/loaders/DRACOLoader.js';
import { KTX2Loader } from 'three/addons/loaders/KTX2Loader.js';
import { MeshoptDecoder } from 'three/addons/libs/meshopt_decoder.module.js';

async function openModel(card) {
  const viewport = card.querySelector('.viewport');
  const status = card.querySelector('output');
  let renderer;
  try {
    renderer = new THREE.WebGLRenderer({antialias: true});
    renderer.setPixelRatio(Math.min(devicePixelRatio, 2));
    renderer.setClearColor(0xe8edf1);
    const scene = new THREE.Scene();
    const camera = new THREE.PerspectiveCamera(45, 1, 0.01, 1000);
    const controls = new OrbitControls(camera, renderer.domElement);
    const ambient = new THREE.HemisphereLight(0xffffff, 0x667387, 2);
    const key = new THREE.DirectionalLight(0xffffff, 3);
    key.position.set(3, 4, 5);
    scene.add(ambient, key);
    const libs = new URL('./vendor/examples/jsm/libs/', import.meta.url);
    const draco = new DRACOLoader().setDecoderPath(new URL('draco/gltf/', libs).href);
    const ktx = new KTX2Loader().setTranscoderPath(new URL('basis/', libs).href).detectSupport(renderer);
    const loader = new GLTFLoader().setDRACOLoader(draco).setKTX2Loader(ktx).setMeshoptDecoder(MeshoptDecoder);
    const {scene: model} = await loader.loadAsync(card.dataset.model);
    const bounds = new THREE.Box3().setFromObject(model);
    const center = bounds.getCenter(new THREE.Vector3());
    const size = bounds.getSize(new THREE.Vector3()).length();
    if (!Number.isFinite(size) || size <= 0) throw new Error('The model contains no visible geometry.');
    model.position.sub(center);
    scene.add(model);
    function frame() {
      camera.position.set(0.75, 0.5, 1).multiplyScalar(size * Math.max(1, 1 / camera.aspect));
      camera.near = size / 1000;
      camera.far = size * 200;
      camera.updateProjectionMatrix();
      controls.target.set(0, 0, 0);
      controls.update();
    }
    viewport.append(renderer.domElement);
    viewport.hidden = false;
    const observer = new ResizeObserver(() => {
      camera.aspect = viewport.clientWidth / viewport.clientHeight;
      camera.updateProjectionMatrix();
      renderer.setSize(viewport.clientWidth, viewport.clientHeight);
    });
    observer.observe(viewport);
    frame();
    card.querySelector('.frame').hidden = false;
    card.querySelector('.frame').onclick = frame;
    card.querySelector('.spin').hidden = false;
    card.querySelector('.spin').onclick = event => {
      controls.autoRotate = !controls.autoRotate;
      event.target.setAttribute('aria-pressed', String(controls.autoRotate));
    };
    renderer.setAnimationLoop(() => {
      controls.update();
      renderer.render(scene, camera);
    });
    status.textContent = 'Drag to orbit, right-drag to pan, scroll to zoom.';
    card.dataset.loaded = 'true';
  } catch (error) {
    renderer?.dispose();
    status.textContent = `Unable to open 3D model. ${error.message}`;
    card.querySelector('.load-model').hidden = false;
  }
}

for (const card of document.querySelectorAll('[data-model]')) {
  card.querySelector('.load-model').onclick = event => {
    event.target.hidden = true;
    card.querySelector('output').textContent = 'Loading model…';
    openModel(card);
  };
}
