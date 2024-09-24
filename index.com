<!DOCTYPE html>
<html lang="ja">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>3D Minecraft-like Game with Terrain and Physics</title>
    <style>
        body { margin: 0; overflow: hidden; }
    </style>
    <script src="https://cdnjs.cloudflare.com/ajax/libs/three.js/r128/three.min.js"></script>
</head>
<body>
<script type="module">
import * as CANNON from 'https://cdn.jsdelivr.net/npm/cannon-es@0.18.0/dist/cannon-es.js';
import SimplexNoise from 'https://cdnjs.cloudflare.com/ajax/libs/simplex-noise/2.4.0/simplex-noise.min.js';

// シーン、カメラ、レンダラーの設定
const scene = new THREE.Scene();
const camera = new THREE.PerspectiveCamera(75, window.innerWidth / window.innerHeight, 0.1, 1000);
const renderer = new THREE.WebGLRenderer();
renderer.setSize(window.innerWidth, window.innerHeight);
document.body.appendChild(renderer.domElement);

// 物理エンジンの設定
const world = new CANNON.World();
world.gravity.set(0, -9.82, 0); // 重力を設定

// プレイヤー用の物理ボディの設定
const playerShape = new CANNON.Sphere(0.5); // 半径0.5の球体
const playerBody = new CANNON.Body({ mass: 1, shape: playerShape });
playerBody.position.set(0, 5, 0);
world.addBody(playerBody);

// プレイヤーの3Dオブジェクト
const playerGeometry = new THREE.SphereGeometry(0.5, 32, 32);
const playerMaterial = new THREE.MeshBasicMaterial({ color: 0xff0000 });
const playerMesh = new THREE.Mesh(playerGeometry, playerMaterial);
scene.add(playerMesh);

// パーリンノイズを使ってリアルな地形を生成
const simplex = new SimplexNoise();
function createTerrain(size, scale, height) {
    const geometry = new THREE.BoxGeometry(1, 1, 1);
    for (let x = -size; x <= size; x++) {
        for (let z = -size; z <= size; z++) {
            const y = Math.floor(simplex.noise2D(x / scale, z / scale) * height); // パーリンノイズで高さを計算
            const material = new THREE.MeshBasicMaterial({ color: y > 0 ? 0x228B22 : 0x1E90FF });
            const cube = new THREE.Mesh(geometry, material);
            cube.position.set(x, y, z);
            scene.add(cube);

            // 物理ボディも作成
            const shape = new CANNON.Box(new CANNON.Vec3(0.5, 0.5, 0.5));
            const body = new CANNON.Body({ mass: 0, shape: shape });
            body.position.set(x, y, z);
            world.addBody(body);
        }
    }
}

// 地形を生成
createTerrain(20, 10, 5); // サイズ20、スケール10、高さ5の地形

// キーボード操作の設定
const keys = { w: false, a: false, s: false, d: false, space: false };

document.addEventListener('keydown', (event) => {
    if (event.key in keys) keys[event.key] = true;
});

document.addEventListener('keyup', (event) => {
    if (event.key in keys) keys[event.key] = false;
});

// ゲームループ
function animate() {
    requestAnimationFrame(animate);

    // プレイヤーの移動
    const speed = 0.1;
    if (keys.w) playerBody.velocity.z = -speed;
    if (keys.s) playerBody.velocity.z = speed;
    if (keys.a) playerBody.velocity.x = -speed;
    if (keys.d) playerBody.velocity.x = speed;
    if (keys.space && playerBody.position.y <= 1) playerBody.velocity.y = 5; // 簡易ジャンプ

    // 物理エンジンの更新
    world.step(1 / 60);

    // 3Dオブジェクトの位置を物理ボディに合わせる
    playerMesh.position.copy(playerBody.position);

    // カメラ追従
    camera.position.x = playerBody.position.x;
    camera.position.y = playerBody.position.y + 3;
    camera.position.z = playerBody.position.z + 5;
    camera.lookAt(playerMesh.position);

    renderer.render(scene, camera);
}

animate();
</script>
</body>
</html>
