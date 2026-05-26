/// Branch class system helpers (Sunkidz vs Normal).

const String sunkidzSystem = 'sunkidz';
const String normalSystem = 'normal';

String normalizeBranchSystemType(String? raw) {
  final t = (raw ?? sunkidzSystem).toLowerCase();
  if (t == 'kreedo') return sunkidzSystem;
  return t;
}

String branchSystemTypeLabel(String? raw) {
  final t = normalizeBranchSystemType(raw);
  if (t == normalSystem) {
    return 'Normal (Nursery/LKG/UKG)';
  }
  return 'Sunkidz (Playschool/1G1/1G2/1G3)';
}

bool isSunkidzSystem(String? raw) =>
    normalizeBranchSystemType(raw) == sunkidzSystem;
